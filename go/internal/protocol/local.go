package protocol

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// LocalVFS implements VFS for local filesystem and mounted/UNC network paths.
type LocalVFS struct{}

// NewLocalVFS returns an initialized LocalVFS.
func NewLocalVFS() *LocalVFS {
	return &LocalVFS{}
}

// ListFiles returns all files directly in dir matching the patterns.
// Ignores directories matching "20*" (archive directory exclusion).
func (v *LocalVFS) ListFiles(dir string, patterns []string) ([]FileInfo, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed reading directory %q: %w", dir, err)
	}

	var results []FileInfo
	for _, entry := range entries {
		name := entry.Name()

		// Skip archive directories /XD 20*
		if entry.IsDir() {
			continue
		}

		if !MatchesAnyGlob(name, patterns) {
			continue
		}

		fi, err := entry.Info()
		if err != nil {
			continue
		}

		results = append(results, FileInfo{
			Name:    name,
			Path:    filepath.Join(dir, name),
			Size:    fi.Size(),
			ModTime: fi.ModTime(),
			IsDir:   false,
		})
	}

	return results, nil
}

// ListDirs returns subdirectories directly inside dir.
func (v *LocalVFS) ListDirs(dir string) ([]FileInfo, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed reading directory %q: %w", dir, err)
	}

	var results []FileInfo
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		fi, err := entry.Info()
		if err != nil {
			continue
		}
		results = append(results, FileInfo{
			Name:    entry.Name(),
			Path:    filepath.Join(dir, entry.Name()),
			Size:    0,
			ModTime: fi.ModTime(),
			IsDir:   true,
		})
	}
	return results, nil
}

// Stat returns metadata for a file or directory.
func (v *LocalVFS) Stat(path string) (*FileInfo, error) {
	fi, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	return &FileInfo{
		Name:    fi.Name(),
		Path:    path,
		Size:    fi.Size(),
		ModTime: fi.ModTime(),
		IsDir:   fi.IsDir(),
	}, nil
}

// OpenRead opens a file for streaming read.
func (v *LocalVFS) OpenRead(path string) (io.ReadCloser, error) {
	return os.Open(path)
}

// WriteAtomic writes content to a temporary file, sets timestamps, and atomically renames.
func (v *LocalVFS) WriteAtomic(path string, r io.Reader, modTime time.Time) (int64, error) {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return 0, fmt.Errorf("failed creating target directory %q: %w", dir, err)
	}

	tmpPath := fmt.Sprintf("%s.%d.tmp", path, time.Now().UnixNano())
	tmpFile, err := os.OpenFile(tmpPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		return 0, fmt.Errorf("failed creating temporary file %q: %w", tmpPath, err)
	}

	// 64KB buffer streaming copy
	buf := make([]byte, 64*1024)
	written, err := io.CopyBuffer(tmpFile, r, buf)
	if err != nil {
		_ = tmpFile.Close()
		_ = os.Remove(tmpPath)
		return 0, fmt.Errorf("failed writing file stream to %q: %w", tmpPath, err)
	}

	// Ensure all bytes flushed to storage
	if err := tmpFile.Sync(); err != nil {
		_ = tmpFile.Close()
		_ = os.Remove(tmpPath)
		return 0, fmt.Errorf("failed syncing temporary file: %w", err)
	}
	_ = tmpFile.Close()

	// Apply timestamps to temp file before rename
	if !modTime.IsZero() {
		_ = os.Chtimes(tmpPath, modTime, modTime)
	}

	// Replace target atomically
	// On Windows, if target exists, remove it first to allow rename
	_ = os.Remove(path)
	if err := os.Rename(tmpPath, path); err != nil {
		// Fallback: copy in place if rename across volumes fails
		copyErr := copyFileInPlace(tmpPath, path)
		_ = os.Remove(tmpPath)
		if copyErr != nil {
			return 0, fmt.Errorf("failed replacing %q: %w", path, err)
		}
	}

	// Re-apply timestamp on final target
	if !modTime.IsZero() {
		_ = os.Chtimes(path, modTime, modTime)
	}

	return written, nil
}

func copyFileInPlace(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.OpenFile(dst, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

// EnsureDir creates directory recursively.
func (v *LocalVFS) EnsureDir(path string) error {
	return os.MkdirAll(path, 0755)
}

// Move renames or moves a file.
func (v *LocalVFS) Move(oldPath, newPath string) error {
	destDir := filepath.Dir(newPath)
	if err := os.MkdirAll(destDir, 0755); err != nil {
		return err
	}
	_ = os.Remove(newPath)
	return os.Rename(oldPath, newPath)
}

// Remove deletes a single file.
func (v *LocalVFS) Remove(path string) error {
	return os.Remove(path)
}

// RemoveAll deletes a path and any children recursively.
func (v *LocalVFS) RemoveAll(path string) error {
	return os.RemoveAll(path)
}

// Close implements VFS.
func (v *LocalVFS) Close() error {
	return nil
}

// CleanPath normalizes slashes for the current OS.
func CleanPath(p string) string {
	p = strings.TrimSpace(p)
	return filepath.Clean(p)
}

