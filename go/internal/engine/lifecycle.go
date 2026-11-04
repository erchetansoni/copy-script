package engine

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"copymaster/internal/logger"
	"copymaster/internal/protocol"
)

var monthFolderRegex = regexp.MustCompile(`^\d{4}-(0[1-9]|1[0-2])$`)

// RunMonthlyArchive moves destination root files from prior months into YYYY-MM subfolders.
func RunMonthlyArchive(destFS protocol.VFS, destPath string, patterns []string, log *logger.Logger, mapName string) (int, error) {
	now := time.Now()
	currentMonthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())

	files, err := destFS.ListFiles(destPath, patterns)
	if err != nil {
		return 0, fmt.Errorf("failed listing destination files for archive: %w", err)
	}

	archivedCount := 0
	for _, f := range files {
		if f.ModTime.Before(currentMonthStart) {
			ym := f.ModTime.Format("2006-01")
			archiveDir := filepath.ToSlash(filepath.Join(destPath, ym))
			if err := destFS.EnsureDir(archiveDir); err != nil {
				log.Log(logger.LevelWarn, "[%s] [DEST ARCHIVE] Failed creating archive directory %s: %v", mapName, archiveDir, err)
				continue
			}

			targetFilePath := filepath.ToSlash(filepath.Join(archiveDir, f.Name))
			if err := destFS.Move(f.Path, targetFilePath); err != nil {
				log.Log(logger.LevelWarn, "[%s] [DEST ARCHIVE] Failed moving %s -> %s: %v", mapName, f.Name, ym, err)
				continue
			}

			log.Log(logger.LevelInfo, "[%s] [DEST ARCHIVE] Moved '%s' (Modified: %s) -> '%s/'",
				mapName, f.Name, f.ModTime.Format("2006-01-02"), ym)
			archivedCount++
		}
	}

	if archivedCount > 0 {
		log.Log(logger.LevelSuccess, "[%s] Monthly Archive: %d file(s) moved to YYYY-MM archive folders.", mapName, archivedCount)
	}
	return archivedCount, nil
}

// RunArchivePurge deletes YYYY-MM destination folders older than retentionMonths.
func RunArchivePurge(destFS protocol.VFS, destPath string, retentionMonths int, log *logger.Logger, mapName string) (int, error) {
	if retentionMonths < 1 {
		return 0, nil
	}

	now := time.Now()
	currentMonthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	cutoffMonth := currentMonthStart.AddDate(0, -retentionMonths, 0)

	dirs, err := destFS.ListDirs(destPath)
	if err != nil {
		return 0, fmt.Errorf("failed listing destination subdirectories: %w", err)
	}

	purgedCount := 0
	for _, d := range dirs {
		if !monthFolderRegex.MatchString(d.Name) {
			continue
		}

		t, err := time.Parse("2006-01", d.Name)
		if err != nil {
			continue
		}

		if t.Before(cutoffMonth) {
			log.Log(logger.LevelWarn, "[%s] [DEST PURGE] Permanently deleting expired archive folder: %s (Cutoff: %s)",
				mapName, d.Name, cutoffMonth.Format("2006-01"))

			if err := destFS.RemoveAll(d.Path); err != nil {
				log.Log(logger.LevelError, "[%s] [DEST PURGE ERROR] Failed removing %s: %v", mapName, d.Name, err)
			} else {
				purgedCount++
			}
		}
	}

	if purgedCount > 0 {
		log.Log(logger.LevelSuccess, "[%s] Destination Purge: %d old monthly archive folder(s) removed.", mapName, purgedCount)
	}
	return purgedCount, nil
}

// RunSourceCleanup deletes source files older than retentionDays ONLY after verifying byte match at destination.
func RunSourceCleanup(srcFS protocol.VFS, srcPath string, destFS protocol.VFS, destPath string, patterns []string, retentionDays int, log *logger.Logger, mapName string) (int, int, error) {
	if retentionDays < 1 {
		return 0, 0, nil
	}

	cutoff := time.Now().AddDate(0, 0, -retentionDays)
	log.Log(logger.LevelInfo, "[%s] [SOURCE CLEANUP] Checking for source files older than %d days (Cutoff: %s)...",
		mapName, retentionDays, cutoff.Format("2006-01-02 15:04"))

	srcFiles, err := srcFS.ListFiles(srcPath, patterns)
	if err != nil {
		return 0, 0, fmt.Errorf("failed listing source files for cleanup: %w", err)
	}

	deletedCount := 0
	skippedCount := 0

	for _, sf := range srcFiles {
		if !sf.ModTime.Before(cutoff) {
			continue
		}

		// Verification: check if file exists at destination root or destination monthly archive
		destRootPath := filepath.ToSlash(filepath.Join(destPath, sf.Name))
		ym := sf.ModTime.Format("2006-01")
		destArchPath := filepath.ToSlash(filepath.Join(destPath, ym, sf.Name))

		verified := false

		// Check dest root
		if df, err := destFS.Stat(destRootPath); err == nil && df != nil {
			if df.Size == sf.Size {
				verified = true
			}
		}

		// Check dest archive
		if !verified {
			if af, err := destFS.Stat(destArchPath); err == nil && af != nil {
				if af.Size == sf.Size {
					verified = true
				}
			}
		}

		if verified {
			if err := srcFS.Remove(sf.Path); err != nil {
				log.Log(logger.LevelError, "[%s] [SOURCE CLEANUP ERROR] Failed to delete %s: %v", mapName, sf.Name, err)
			} else {
				log.Log(logger.LevelSuccess, "[%s] [SOURCE CLEANUP] Deleted verified source file: %s (Modified: %s)",
					mapName, sf.Name, sf.ModTime.Format("2006-01-02"))
				deletedCount++
			}
		} else {
			log.Log(logger.LevelWarn, "[%s] [SOURCE CLEANUP] SKIPPED: %s is older than %d days but is NOT yet verified at destination.",
				mapName, sf.Name, retentionDays)
			skippedCount++
		}
	}

	if deletedCount > 0 || skippedCount > 0 {
		log.Log(logger.LevelInfo, "[%s] Source Cleanup: %d deleted, %d unverified.", mapName, deletedCount, skippedCount)
	}

	return deletedCount, skippedCount, nil
}

// IsAlreadyArchived checks if a source file has already been archived in destination YYYY-MM to prevent re-copying.
func IsAlreadyArchived(destFS protocol.VFS, destPath string, srcFile protocol.FileInfo) bool {
	now := time.Now()
	curMonthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	if !srcFile.ModTime.Before(curMonthStart) {
		return false
	}

	ym := srcFile.ModTime.Format("2006-01")
	archPath := filepath.ToSlash(filepath.Join(destPath, ym, srcFile.Name))
	df, err := destFS.Stat(archPath)
	if err == nil && df != nil && df.Size == srcFile.Size {
		return true
	}
	return false
}

// CleanSlash normalizes slashes for cross-platform path comparisons.
func CleanSlash(p string) string {
	return strings.ReplaceAll(p, "\\", "/")
}

