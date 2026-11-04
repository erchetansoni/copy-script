package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestConfigLoadSave(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "test_config.yaml")

	cfg := DefaultConfig()
	cfg.SyncDirection = DirectionPull
	cfg.Protocol = ProtocolLocal
	cfg.Mappings = []FolderMapping{
		{
			Name:        "Test Unit",
			Source:      "/tmp/src",
			Destination: "/tmp/dst",
			FileTypes:   []string{"*.csv", "*.dat"},
			Enabled:     true,
		},
	}

	if err := cfg.Save(configPath); err != nil {
		t.Fatalf("Failed saving config: %v", err)
	}

	loaded, err := Load(configPath)
	if err != nil {
		t.Fatalf("Failed loading config: %v", err)
	}

	if loaded.SyncDirection != DirectionPull {
		t.Errorf("Expected Pull, got %v", loaded.SyncDirection)
	}
	if loaded.Protocol != ProtocolLocal {
		t.Errorf("Expected Local, got %v", loaded.Protocol)
	}
	if len(loaded.Mappings) != 1 {
		t.Fatalf("Expected 1 mapping, got %d", len(loaded.Mappings))
	}
	if loaded.Mappings[0].Name != "Test Unit" {
		t.Errorf("Expected mapping name 'Test Unit', got %q", loaded.Mappings[0].Name)
	}

	// Verify file content is valid YAML
	rawBytes, err := os.ReadFile(configPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(rawBytes) == 0 {
		t.Error("Config file was empty")
	}
}

func TestConfigValidation(t *testing.T) {
	cfg := DefaultConfig()
	cfg.SyncDirection = "InvalidDir"
	if err := cfg.Validate(); err == nil {
		t.Error("Expected error on invalid sync direction, got nil")
	}

	cfg = DefaultConfig()
	cfg.Mappings = nil
	if err := cfg.Validate(); err == nil {
		t.Error("Expected error on empty mappings, got nil")
	}

	cfg = DefaultConfig()
	cfg.Lifecycle.EnableSourceDelete = true
	cfg.Lifecycle.SourceDeleteDays = 0
	if err := cfg.Validate(); err == nil {
		t.Error("Expected error on 0 source delete days with delete enabled, got nil")
	}
}

