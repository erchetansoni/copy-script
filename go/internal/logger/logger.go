package logger

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"copymaster/internal/config"
)

// Level indicates log severity.
type Level string

const (
	LevelInfo    Level = "INFO"
	LevelSuccess Level = "SUCCESS"
	LevelWarn    Level = "WARN"
	LevelError   Level = "ERROR"
)

// LogListener defines a callback function invoked whenever a message is logged.
type LogListener func(lvl Level, timestamp string, msg string)

// Logger handles thread-safe structured logging, dual-file output, and automatic log rotation.
type Logger struct {
	mu            sync.Mutex
	cfg           config.LoggingConfig
	summaryPath   string
	detailPath    string
	summaryFile   *os.File
	detailFile    *os.File
	consoleOutput bool
	listener      LogListener
}

// New creates and initializes a Logger instance.
func New(cfg config.LoggingConfig) (*Logger, error) {
	if err := os.MkdirAll(cfg.LogFolder, 0755); err != nil {
		return nil, fmt.Errorf("failed creating log directory %q: %w", cfg.LogFolder, err)
	}

	summaryPath := filepath.Join(cfg.LogFolder, "copymaster_summary.log")
	detailPath := filepath.Join(cfg.LogFolder, "copymaster_detail.log")

	sf, err := os.OpenFile(summaryPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed opening summary log: %w", err)
	}

	df, err := os.OpenFile(detailPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		sf.Close()
		return nil, fmt.Errorf("failed opening detail log: %w", err)
	}

	l := &Logger{
		cfg:           cfg,
		summaryPath:   summaryPath,
		detailPath:    detailPath,
		summaryFile:   sf,
		detailFile:    df,
		consoleOutput: cfg.ConsoleOutput,
	}

	// Run initial cleanup of aged log archives
	l.cleanupAgedArchives()

	return l, nil
}

// SetListener registers a callback listener for log events (e.g. for TUI console display).
func (l *Logger) SetListener(listener LogListener) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.listener = listener
}

// SetConsoleOutput enables or disables direct stdout writing.
func (l *Logger) SetConsoleOutput(enabled bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.consoleOutput = enabled
}

// Close flushes and closes active log files.
func (l *Logger) Close() error {
	l.mu.Lock()
	defer l.mu.Unlock()

	var errs []string
	if l.summaryFile != nil {
		if err := l.summaryFile.Close(); err != nil {
			errs = append(errs, err.Error())
		}
		l.summaryFile = nil
	}
	if l.detailFile != nil {
		if err := l.detailFile.Close(); err != nil {
			errs = append(errs, err.Error())
		}
		l.detailFile = nil
	}
	if len(errs) > 0 {
		return fmt.Errorf("errors closing log files: %s", strings.Join(errs, "; "))
	}
	return nil
}

// Log writes an operational message to the summary log (and console).
func (l *Logger) Log(lvl Level, format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	formatted := fmt.Sprintf("%s [%s] %s\n", timestamp, lvl, msg)

	l.mu.Lock()
	defer l.mu.Unlock()

	if l.consoleOutput {
		var colorPrefix, colorReset string
		switch lvl {
		case LevelSuccess:
			colorPrefix = "\033[32m" // Green
			colorReset = "\033[0m"
		case LevelWarn:
			colorPrefix = "\033[33m" // Yellow
			colorReset = "\033[0m"
		case LevelError:
			colorPrefix = "\033[31m" // Red
			colorReset = "\033[0m"
		case LevelInfo:
			colorPrefix = "\033[36m" // Cyan
			colorReset = "\033[0m"
		}
		fmt.Printf("%s%s [%s]%s %s\n", colorPrefix, timestamp, lvl, colorReset, msg)
	}

	if l.summaryFile != nil {
		_, _ = io.WriteString(l.summaryFile, formatted)
		l.checkRotation(l.summaryFile, l.summaryPath, "copymaster_summary")
	}

	if l.listener != nil {
		l.listener(lvl, timestamp, msg)
	}
}

// LogDetail writes detailed file-by-file transfer records to the detail log.
func (l *Logger) LogDetail(format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	formatted := fmt.Sprintf("%s %s\n", timestamp, msg)

	l.mu.Lock()
	defer l.mu.Unlock()

	if l.detailFile != nil {
		_, _ = io.WriteString(l.detailFile, formatted)
		l.checkRotation(l.detailFile, l.detailPath, "copymaster_detail")
	}
}

// checkRotation checks if the target log file exceeds the max size threshold and rotates it.
// Caller MUST hold l.mu.
func (l *Logger) checkRotation(file *os.File, path string, prefix string) {
	fi, err := file.Stat()
	if err != nil {
		return
	}

	maxBytes := int64(l.cfg.MaxLogSizeMB) * 1024 * 1024
	if fi.Size() < maxBytes {
		return
	}

	// Close active file
	_ = file.Close()

	// Timestamped archive name
	archiveName := fmt.Sprintf("%s_%s.log", prefix, time.Now().Format("20060102_150405"))
	archivePath := filepath.Join(l.cfg.LogFolder, archiveName)
	_ = os.Rename(path, archivePath)

	// Reopen fresh active log
	newF, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err == nil {
		if path == l.summaryPath {
			l.summaryFile = newF
		} else {
			l.detailFile = newF
		}
	}

	l.cleanupAgedArchives()
}

// cleanupAgedArchives enforces retention days and max archive count.
func (l *Logger) cleanupAgedArchives() {
	entries, err := os.ReadDir(l.cfg.LogFolder)
	if err != nil {
		return
	}

	type fileWithAge struct {
		path    string
		modTime time.Time
	}

	cutoff := time.Now().AddDate(0, 0, -l.cfg.LogRetentionDays)
	var archives []fileWithAge

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(name, ".log") {
			continue
		}
		// Skip active logs
		if name == "copymaster_summary.log" || name == "copymaster_detail.log" {
			continue
		}

		fi, err := entry.Info()
		if err != nil {
			continue
		}

		fullPath := filepath.Join(l.cfg.LogFolder, name)

		// Age-based deletion
		if fi.ModTime().Before(cutoff) {
			_ = os.Remove(fullPath)
			continue
		}

		archives = append(archives, fileWithAge{path: fullPath, modTime: fi.ModTime()})
	}

	// Count-based deletion
	if len(archives) > l.cfg.MaxArchivedLogs {
		sort.Slice(archives, func(i, j int) bool {
			return archives[i].modTime.Before(archives[j].modTime)
		})
		excess := len(archives) - l.cfg.MaxArchivedLogs
		for i := 0; i < excess; i++ {
			_ = os.Remove(archives[i].path)
		}
	}
}

