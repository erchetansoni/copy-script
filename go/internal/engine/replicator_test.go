package engine

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"copymaster/internal/config"
	"copymaster/internal/logger"
)

func TestReplicatorAndLifecycleE2E(t *testing.T) {
	tmpDir := t.TempDir()
	srcDir := filepath.Join(tmpDir, "source")
	destDir := filepath.Join(tmpDir, "dest")
	logDir := filepath.Join(tmpDir, "logs")

	_ = os.MkdirAll(srcDir, 0755)
	_ = os.MkdirAll(destDir, 0755)
	_ = os.MkdirAll(logDir, 0755)

	now := time.Now()
	// Simulated dates:
	today := now
	priorMonth := now.AddDate(0, -1, 0)
	twoMonthsAgo := now.AddDate(0, -2, 0)
	eightMonthsAgo := now.AddDate(0, -8, 0)

	// Create test files at source:
	// 1. Active file today
	activePath := filepath.Join(srcDir, "Active_CurrentMonth.csv")
	_ = os.WriteFile(activePath, []byte("col1,col2\nactive_value,123\n"), 0644)
	_ = os.Chtimes(activePath, today, today)

	// 2. Prior month file
	priorPath := filepath.Join(srcDir, "Archive_PriorMonth.csv")
	_ = os.WriteFile(priorPath, []byte("col1,col2\nprior_value,456\n"), 0644)
	_ = os.Chtimes(priorPath, priorMonth, priorMonth)

	// 3. Old file (>30 days ago)
	oldPath := filepath.Join(srcDir, "Cleanup_OldFile.csv")
	_ = os.WriteFile(oldPath, []byte("col1,col2\nold_value,789\n"), 0644)
	_ = os.Chtimes(oldPath, twoMonthsAgo, twoMonthsAgo)

	// Pre-create historical archive folders in dest:
	// Expired archive (8 months ago)
	expiredDirName := eightMonthsAgo.Format("2006-01")
	expiredDirPath := filepath.Join(destDir, expiredDirName)
	_ = os.MkdirAll(expiredDirPath, 0755)
	_ = os.WriteFile(filepath.Join(expiredDirPath, "expired.csv"), []byte("expired"), 0644)

	// Retained archive (2 months ago)
	retainedDirName := twoMonthsAgo.Format("2006-01")
	retainedDirPath := filepath.Join(destDir, retainedDirName)
	_ = os.MkdirAll(retainedDirPath, 0755)
	_ = os.WriteFile(filepath.Join(retainedDirPath, "retained.csv"), []byte("retained"), 0644)

	cfg := &config.Config{
		SyncDirection: config.DirectionLocal,
		Protocol:      config.ProtocolLocal,
		Mappings: []config.FolderMapping{
			{
				Name:        "E2E Integration Test",
				Source:      srcDir,
				Destination: destDir,
				FileTypes:   []string{"*.csv"},
				Enabled:     true,
			},
		},
		Lifecycle: config.LifecycleConfig{
			EnableSourceDelete:       true,
			SourceDeleteDays:         30,
			EnableDestMonthlyArchive: true,
			EnableDestArchiveDelete:  true,
			DestArchiveDeleteMonths:  6,
		},
		Logging: config.LoggingConfig{
			LogFolder:        logDir,
			MaxLogSizeMB:     10,
			MaxArchivedLogs:  10,
			LogRetentionDays: 30,
			ConsoleOutput:    false,
		},
		Scheduler: config.SchedulerConfig{
			IntervalSeconds:  60,
			RunOnce:          true,
			RetryAttempts:    3,
			RetryWaitSeconds: 1,
		},
	}

	log, err := logger.New(cfg.Logging)
	if err != nil {
		t.Fatalf("Failed creating logger: %v", err)
	}
	defer log.Close()

	eng := NewEngine(cfg, log)

	// ==========================================================
	// PASS 1: Execution
	// ==========================================================
	copied, failed, skipped := eng.RunCycle()
	if failed > 0 {
		t.Errorf("Pass 1: Expected 0 failures, got %d", failed)
	}
	if copied != 3 {
		t.Errorf("Pass 1: Expected 3 copied files, got %d", copied)
	}

	// Assertions after Pass 1:
	// 1. Current month file must exist at destination root
	destActive := filepath.Join(destDir, "Active_CurrentMonth.csv")
	if _, err := os.Stat(destActive); os.IsNotExist(err) {
		t.Errorf("Assertion Failed: Active_CurrentMonth.csv does not exist at dest root")
	}

	// 2. Prior month file must have been moved to YYYY-MM
	priorYm := priorMonth.Format("2006-01")
	destPriorArchived := filepath.Join(destDir, priorYm, "Archive_PriorMonth.csv")
	if _, err := os.Stat(destPriorArchived); os.IsNotExist(err) {
		t.Errorf("Assertion Failed: Archive_PriorMonth.csv not found in monthly archive %s", priorYm)
	}
	// And must NOT exist at dest root
	destPriorRoot := filepath.Join(destDir, "Archive_PriorMonth.csv")
	if _, err := os.Stat(destPriorRoot); err == nil {
		t.Errorf("Assertion Failed: Archive_PriorMonth.csv was not moved out of dest root")
	}

	// 3. Old file (>30 days) must have been moved to YYYY-MM
	oldYm := twoMonthsAgo.Format("2006-01")
	destOldArchived := filepath.Join(destDir, oldYm, "Cleanup_OldFile.csv")
	if _, err := os.Stat(destOldArchived); os.IsNotExist(err) {
		t.Errorf("Assertion Failed: Cleanup_OldFile.csv not found in monthly archive %s", oldYm)
	}

	// 4. Old file (>30 days) must have been safely deleted from source after verification
	if _, err := os.Stat(oldPath); err == nil {
		t.Errorf("Assertion Failed: Cleanup_OldFile.csv still exists at source (should be deleted)")
	}

	// 5. Active file (<30 days) must STILL exist at source
	if _, err := os.Stat(activePath); os.IsNotExist(err) {
		t.Errorf("Assertion Failed: Active_CurrentMonth.csv was prematurely deleted from source")
	}

	// 6. Expired archive folder (>6 months) must be permanently purged
	if _, err := os.Stat(expiredDirPath); err == nil {
		t.Errorf("Assertion Failed: Expired archive folder %s was not purged", expiredDirName)
	}

	// 7. Retained archive folder (<6 months) must be preserved
	if _, err := os.Stat(retainedDirPath); os.IsNotExist(err) {
		t.Errorf("Assertion Failed: Retained archive folder %s was improperly deleted", retainedDirName)
	}

	// ==========================================================
	// PASS 2: Loop Prevention & Skip Assertion
	// ==========================================================
	copied2, failed2, skipped2 := eng.RunCycle()
	if failed2 > 0 {
		t.Errorf("Pass 2: Expected 0 failures, got %d", failed2)
	}
	if copied2 > 0 {
		t.Errorf("Pass 2: Expected 0 copied files on re-run (loop prevention), got %d", copied2)
	}
	if skipped2 < 1 {
		t.Errorf("Pass 2: Expected at least 1 skipped file, got %d (skipped: %d, copied: %d)", skipped, skipped2, copied2)
	}
}
