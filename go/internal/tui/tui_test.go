package tui

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"copymaster/internal/config"
)

func TestSSHKeyGenerationAndSave(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "copymaster_key_test*")
	if err != nil {
		t.Fatalf("failed creating temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	key, err := GenerateEd25519KeyPair("test@copymaster")
	if err != nil {
		t.Fatalf("GenerateEd25519KeyPair failed: %v", err)
	}

	if !strings.Contains(key.PrivateKeyPEM, "OPENSSH PRIVATE KEY") {
		t.Errorf("Expected PEM block to contain OPENSSH PRIVATE KEY, got: %s", key.PrivateKeyPEM)
	}

	if !strings.HasPrefix(key.PublicKey, "ssh-ed25519 ") {
		t.Errorf("Expected public key to start with ssh-ed25519, got: %s", key.PublicKey)
	}

	targetPriv := filepath.Join(tmpDir, "id_ed25519")
	if err := SaveSSHKeyPair(targetPriv, key); err != nil {
		t.Fatalf("SaveSSHKeyPair failed: %v", err)
	}

	if _, err := os.Stat(targetPriv); err != nil {
		t.Errorf("Private key file was not created: %v", err)
	}

	targetPub := targetPriv + ".pub"
	if _, err := os.Stat(targetPub); err != nil {
		t.Errorf("Public key file was not created: %v", err)
	}
}

func TestServerGuideGeneration(t *testing.T) {
	guideSFTP := GenerateServerGuide("SFTP", "192.168.1.100", 22, "backup_user", "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...")
	if !strings.Contains(guideSFTP, "authorized_keys") {
		t.Errorf("Expected SFTP guide to contain authorized_keys instructions")
	}
	if !strings.Contains(guideSFTP, "backup_user") {
		t.Errorf("Expected SFTP guide to reference backup_user")
	}

	guideSMB := GenerateServerGuide("SMB", "192.168.1.50", 445, "ot_user", "")
	if !strings.Contains(guideSMB, "New-SmbShare") {
		t.Errorf("Expected SMB guide to contain New-SmbShare instructions")
	}
}

func TestImportFromPowerShell(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "copymaster_ps1_test*")
	if err != nil {
		t.Fatalf("failed creating temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	sampleScript := `
# Sample CopyMaster Script
$SyncDirection = "Push"
$SourceProtocol = "SFTP"
$RemoteHost = "10.0.0.99"
$RemotePort = 2222
$RemoteUsername = "svc_replication"
$SshPrivateKeyPath = "C:\Keys\id_ed25519"
$EnableSourceDelete = $true
$SourceDeleteDays = 14
$EnableDestMonthlyArchive = $true
$EnableDestArchiveDelete = $true
$DestArchiveDeleteMonths = 6
$LogFolder = "C:\Logs\CopyMaster"
$MaxLogSizeMB = 25
$LogRetentionDays = 60

$FolderMappings = @(
    @{ Name = "Telemetry"; Source = "C:\Data\Telemetry"; Destination = "/var/data/telemetry"; Types = "*.csv, *.dat" }
)
`
	psPath := filepath.Join(tmpDir, "CopyScript.ps1")
	if err := os.WriteFile(psPath, []byte(sampleScript), 0644); err != nil {
		t.Fatalf("failed writing test script: %v", err)
	}

	cfg, err := LoadFromFile(psPath)
	if err != nil {
		t.Fatalf("LoadFromFile failed on .ps1: %v", err)
	}

	if cfg.SyncDirection != config.DirectionPush {
		t.Errorf("Expected Push, got %s", cfg.SyncDirection)
	}
	if cfg.Protocol != "SFTP" {
		t.Errorf("Expected SFTP, got %s", cfg.Protocol)
	}
	if cfg.Endpoint.Host != "10.0.0.99" {
		t.Errorf("Expected 10.0.0.99, got %s", cfg.Endpoint.Host)
	}
	if cfg.Endpoint.Port != 2222 {
		t.Errorf("Expected 2222, got %d", cfg.Endpoint.Port)
	}
	if cfg.Endpoint.Username != "svc_replication" {
		t.Errorf("Expected svc_replication, got %s", cfg.Endpoint.Username)
	}
	if !cfg.Lifecycle.EnableSourceDelete || cfg.Lifecycle.SourceDeleteDays != 14 {
		t.Errorf("Unexpected lifecycle: %+v", cfg.Lifecycle)
	}
	if len(cfg.Mappings) != 1 || cfg.Mappings[0].Name != "Telemetry" {
		t.Errorf("Unexpected mappings: %+v", cfg.Mappings)
	}
}

