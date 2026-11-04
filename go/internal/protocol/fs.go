package protocol

import (
	"io"
	"path/filepath"
	"strings"
	"time"
)

// FileInfo represents cross-platform metadata for a file or directory.
type FileInfo struct {
	Name    string
	Path    string
	Size    int64
	ModTime time.Time
	IsDir   bool
}

// VFS represents a Virtual File System abstraction for Local and Remote (SFTP) files.
type VFS interface {
	// ListFiles returns non-directory files directly inside dir matching any of the glob patterns.
	// Skips directories matching archive pattern "20*".
	ListFiles(dir string, patterns []string) ([]FileInfo, error)

	// ListDirs returns subdirectories directly inside dir.
	ListDirs(dir string) ([]FileInfo, error)

	// Stat returns metadata for a file or directory.
	Stat(path string) (*FileInfo, error)

	// OpenRead opens a file for reading.
	OpenRead(path string) (io.ReadCloser, error)

	// WriteAtomic writes content from r to a temporary file, sets modTime, and atomically replaces path.
	WriteAtomic(path string, r io.Reader, modTime time.Time) (int64, error)

	// EnsureDir creates the directory path if it does not already exist.
	EnsureDir(path string) error

	// Move renames or moves a file from oldPath to newPath.
	Move(oldPath, newPath string) error

	// Remove deletes a single file.
	Remove(path string) error

	// RemoveAll deletes a path and any children it contains.
	RemoveAll(path string) error

	// Close cleans up connections or resources.
	Close() error
}

// MatchesAnyGlob checks if a filename matches any pattern in patterns (e.g. "*.csv", "*.*", "*").
func MatchesAnyGlob(name string, patterns []string) bool {
	if len(patterns) == 0 {
		return true
	}
	for _, p := range patterns {
		p = strings.TrimSpace(p)
		if p == "" || p == "*" || p == "*.*" {
			return true
		}
		// Case-insensitive match on Windows / standard industrial file naming
		matched, err := filepath.Match(strings.ToLower(p), strings.ToLower(name))
		if err == nil && matched {
			return true
		}
	}
	return false
}

