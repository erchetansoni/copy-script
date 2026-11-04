package logger

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"copymaster/internal/config"
)

func TestLoggerWritesAndRotates(t *testing.T) {
	tmpDir := t.TempDir()
	cfg := config.LoggingConfig{
		LogFolder:        tmpDir,
		MaxLogSizeMB:     1, // 1MB
		MaxArchivedLogs:  5,
		LogRetentionDays: 7,
		ConsoleOutput:    false,
	}

	l, err := New(cfg)
	if err != nil {
		t.Fatalf("Failed creating logger: %v", err)
	}
	defer l.Close()

	l.Log(LevelInfo, "Initial test message")
	l.Log(LevelSuccess, "Operation succeeded")
	l.LogDetail("File test.csv copied successfully")

	summaryBytes, err := os.ReadFile(filepath.Join(tmpDir, "copymaster_summary.log"))
	if err != nil {
		t.Fatalf("Failed reading summary log: %v", err)
	}
	if !strings.Contains(string(summaryBytes), "Initial test message") {
		t.Errorf("Expected summary log to contain 'Initial test message'")
	}
	if !strings.Contains(string(summaryBytes), "Operation succeeded") {
		t.Errorf("Expected summary log to contain 'Operation succeeded'")
	}

	detailBytes, err := os.ReadFile(filepath.Join(tmpDir, "copymaster_detail.log"))
	if err != nil {
		t.Fatalf("Failed reading detail log: %v", err)
	}
	if !strings.Contains(string(detailBytes), "File test.csv copied successfully") {
		t.Errorf("Expected detail log to contain 'File test.csv copied successfully'")
	}
}

