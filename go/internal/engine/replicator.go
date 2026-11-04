package engine

import (
	"fmt"
	"math"
	"path/filepath"
	"time"

	"copymaster/internal/config"
	"copymaster/internal/logger"
	"copymaster/internal/protocol"
)

// MappingResult tracks counts for a single mapping synchronization.
type MappingResult struct {
	MappingName string
	Copied      int
	Skipped     int
	Failed      int
	BytesCopied int64
}

// SyncMapping replicates files for a single folder mapping according to direction, protocol, and lifecycle rules.
func SyncMapping(
	mapping config.FolderMapping,
	cfg *config.Config,
	localFS protocol.VFS,
	remoteFS protocol.VFS,
	log *logger.Logger,
) MappingResult {
	res := MappingResult{MappingName: mapping.Name}

	if !mapping.Enabled {
		log.Log(logger.LevelInfo, "[%s] Mapping is disabled, skipping.", mapping.Name)
		return res
	}

	var srcFS, destFS protocol.VFS
	var srcPath, destPath string

	switch cfg.SyncDirection {
	case config.DirectionPush:
		// Local Source -> Remote Destination
		srcFS = localFS
		srcPath = mapping.Source
		if cfg.Protocol == config.ProtocolSFTP && remoteFS != nil {
			destFS = remoteFS
		} else {
			destFS = localFS
		}
		destPath = mapping.Destination

	case config.DirectionPull:
		// Remote Source -> Local Destination
		if cfg.Protocol == config.ProtocolSFTP && remoteFS != nil {
			srcFS = remoteFS
		} else {
			srcFS = localFS
		}
		srcPath = mapping.Source
		destFS = localFS
		destPath = mapping.Destination

	case config.DirectionLocal:
		// Local/UNC -> Local/UNC
		srcFS = localFS
		srcPath = mapping.Source
		destFS = localFS
		destPath = mapping.Destination
	}

	log.Log(logger.LevelInfo, "[%s] Starting Replication (%s | %s)", mapping.Name, cfg.Protocol, cfg.SyncDirection)
	log.Log(logger.LevelInfo, "[%s] Source: %s", mapping.Name, srcPath)
	log.Log(logger.LevelInfo, "[%s] Dest  : %s", mapping.Name, destPath)

	// Ensure destination directory exists
	if err := destFS.EnsureDir(destPath); err != nil {
		log.Log(logger.LevelError, "[%s] Failed creating destination directory %s: %v", mapping.Name, destPath, err)
		res.Failed++
		return res
	}

	// List source files
	srcFiles, err := srcFS.ListFiles(srcPath, mapping.FileTypes)
	if err != nil {
		log.Log(logger.LevelError, "[%s] Failed listing source directory %s: %v", mapping.Name, srcPath, err)
		res.Failed++
		return res
	}

	log.Log(logger.LevelInfo, "[%s] Discovered %d matching source file(s)", mapping.Name, len(srcFiles))

	for _, sf := range srcFiles {
		// 1. Loop prevention check: if file was already archived in YYYY-MM, don't copy back to root
		if cfg.Lifecycle.EnableDestMonthlyArchive && IsAlreadyArchived(destFS, destPath, sf) {
			log.LogDetail("[%s] [SKIP-ARCHIVED] %s already present in destination monthly archive.", mapping.Name, sf.Name)
			res.Skipped++
			continue
		}

		targetFilePath := filepath.ToSlash(filepath.Join(destPath, sf.Name))

		// 2. Check if destination file exists and is identical/newer (Robocopy /XO /FFT semantics)
		destInfo, err := destFS.Stat(targetFilePath)
		if err == nil && destInfo != nil {
			// Tolerance: 2 seconds for FAT/SMB timestamp granularity
			timeDiff := destInfo.ModTime.Sub(sf.ModTime)
			if math.Abs(timeDiff.Seconds()) <= 2.0 && destInfo.Size == sf.Size {
				log.LogDetail("[%s] [SKIP-MATCH] %s is identical at destination (Size: %d bytes).", mapping.Name, sf.Name, sf.Size)
				res.Skipped++
				continue
			}
			if destInfo.ModTime.After(sf.ModTime) && destInfo.Size == sf.Size {
				log.LogDetail("[%s] [SKIP-OLDER] Destination %s is newer or equal (Dest: %s, Src: %s).",
					mapping.Name, sf.Name, destInfo.ModTime.Format(time.RFC3339), sf.ModTime.Format(time.RFC3339))
				res.Skipped++
				continue
			}
		}

		// 3. Replicate file
		startCopy := time.Now()
		r, err := srcFS.OpenRead(sf.Path)
		if err != nil {
			log.Log(logger.LevelError, "[%s] [READ ERROR] Failed opening source file %s: %v", mapping.Name, sf.Name, err)
			res.Failed++
			continue
		}

		bytesWritten, err := destFS.WriteAtomic(targetFilePath, r, sf.ModTime)
		_ = r.Close()

		if err != nil {
			log.Log(logger.LevelError, "[%s] [WRITE ERROR] Failed replicating %s: %v", mapping.Name, sf.Name, err)
			res.Failed++
			continue
		}

		duration := time.Since(startCopy)
		log.Log(logger.LevelSuccess, "[%s] Replicated: %s (%s in %v)",
			mapping.Name, sf.Name, formatBytes(bytesWritten), duration.Round(time.Millisecond))
		log.LogDetail("[%s] [COPIED] %s -> %s (%d bytes, %v)",
			mapping.Name, sf.Path, targetFilePath, bytesWritten, duration)

		res.Copied++
		res.BytesCopied += bytesWritten
	}

	// 4. Lifecycle Policies:
	// A: Destination Monthly Auto-Archive
	if cfg.Lifecycle.EnableDestMonthlyArchive {
		_, _ = RunMonthlyArchive(destFS, destPath, mapping.FileTypes, log, mapping.Name)
	}

	// B: Destination Archive Purge
	if cfg.Lifecycle.EnableDestArchiveDelete {
		_, _ = RunArchivePurge(destFS, destPath, cfg.Lifecycle.DestArchiveDeleteMonths, log, mapping.Name)
	}

	// C: Verified Remote Source Cleanup
	if cfg.Lifecycle.EnableSourceDelete {
		_, _, _ = RunSourceCleanup(srcFS, srcPath, destFS, destPath, mapping.FileTypes, cfg.Lifecycle.SourceDeleteDays, log, mapping.Name)
	}

	return res
}

func formatBytes(b int64) string {
	const unit = 1024
	if b < unit {
		return fmt.Sprintf("%d B", b)
	}
	div, exp := int64(unit), 0
	for n := b / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(b)/float64(div), "KMGTPE"[exp])
}

