package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// SyncDirection defines whether data is pushed to remote, pulled from remote, or copied locally.
type SyncDirection string

const (
	DirectionPush  SyncDirection = "Push"  // Local Source -> Remote Destination
	DirectionPull  SyncDirection = "Pull"  // Remote Source -> Local Destination
	DirectionLocal SyncDirection = "Local" // Local/UNC Source -> Local/UNC Destination
)

// Protocol defines the network protocol.
type Protocol string

const (
	ProtocolLocal Protocol = "Local" // Local filesystem or native OS UNC share
	ProtocolSMB   Protocol = "SMB"   // Server Message Block (UNC)
	ProtocolSFTP  Protocol = "SFTP"  // SSH File Transfer Protocol
)

// FolderMapping defines a single replication pair.
type FolderMapping struct {
	Name        string   `yaml:"name"`
	Source      string   `yaml:"source"`
	Destination string   `yaml:"destination"`
	FileTypes   []string `yaml:"file_types"`
	Enabled     bool     `yaml:"enabled"`
}

// EndpointConfig contains authentication and connection parameters for remote servers.
type EndpointConfig struct {
	Host           string `yaml:"host"`
	Port           int    `yaml:"port"`
	Username       string `yaml:"username"`
	Password       string `yaml:"password"`
	PrivateKeyPath string `yaml:"private_key_path"`
	KeyPassphrase  string `yaml:"key_passphrase"`
}

// LifecycleConfig controls data archival, purging, and source cleanup.
type LifecycleConfig struct {
	EnableSourceDelete       bool `yaml:"enable_source_delete"`
	SourceDeleteDays         int  `yaml:"source_delete_days"`
	EnableDestMonthlyArchive bool `yaml:"enable_dest_monthly_archive"`
	EnableDestArchiveDelete  bool `yaml:"enable_dest_archive_delete"`
	DestArchiveDeleteMonths  int  `yaml:"dest_archive_delete_months"`
}

// LoggingConfig defines log rotation and retention policies.
type LoggingConfig struct {
	LogFolder        string `yaml:"log_folder"`
	MaxLogSizeMB     int    `yaml:"max_log_size_mb"`
	MaxArchivedLogs  int    `yaml:"max_archived_logs"`
	LogRetentionDays int    `yaml:"log_retention_days"`
	ConsoleOutput    bool   `yaml:"console_output"`
}

// SchedulerConfig controls continuous loop timing and retries.
type SchedulerConfig struct {
	IntervalSeconds  int  `yaml:"interval_seconds"`
	RunOnce          bool `yaml:"run_once"`
	RetryAttempts    int  `yaml:"retry_attempts"`
	RetryWaitSeconds int  `yaml:"retry_wait_seconds"`
}

// Config represents the complete CopyMaster configuration.
type Config struct {
	SyncDirection SyncDirection   `yaml:"sync_direction"`
	Protocol      Protocol        `yaml:"protocol"`
	Endpoint      EndpointConfig  `yaml:"endpoint"`
	Mappings      []FolderMapping `yaml:"mappings"`
	Lifecycle     LifecycleConfig `yaml:"lifecycle"`
	Logging       LoggingConfig   `yaml:"logging"`
	Scheduler     SchedulerConfig `yaml:"scheduler"`
}

// DefaultConfig returns safe, production-ready default values.
func DefaultConfig() *Config {
	return &Config{
		SyncDirection: DirectionLocal,
		Protocol:      ProtocolLocal,
		Endpoint: EndpointConfig{
			Host:           "",
			Port:           22,
			Username:       "",
			Password:       "",
			PrivateKeyPath: "",
			KeyPassphrase:  "",
		},
		Mappings: []FolderMapping{
			{
				Name:        "Sample Data",
				Source:      "./data_source",
				Destination: "./data_dest",
				FileTypes:   []string{"*.*"},
				Enabled:     true,
			},
		},
		Lifecycle: LifecycleConfig{
			EnableSourceDelete:       false,
			SourceDeleteDays:         30,
			EnableDestMonthlyArchive: true,
			EnableDestArchiveDelete:  false,
			DestArchiveDeleteMonths:  6,
		},
		Logging: LoggingConfig{
			LogFolder:        "./logs",
			MaxLogSizeMB:     10,
			MaxArchivedLogs:  20,
			LogRetentionDays: 30,
			ConsoleOutput:    true,
		},
		Scheduler: SchedulerConfig{
			IntervalSeconds:  60,
			RunOnce:          false,
			RetryAttempts:    5,
			RetryWaitSeconds: 15,
		},
	}
}

// Load reads and parses a YAML configuration file.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed reading config file: %w", err)
	}

	cfg := DefaultConfig()
	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, fmt.Errorf("failed parsing config YAML: %w", err)
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// Save serializes the configuration to a YAML file.
func (c *Config) Save(path string) error {
	dir := filepath.Dir(path)
	if dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed creating config directory: %w", err)
		}
	}

	data, err := yaml.Marshal(c)
	if err != nil {
		return fmt.Errorf("failed marshaling config to YAML: %w", err)
	}

	header := []byte("# ====================================================================\n# COPY MASTER CONFIGURATION (INDUSTRIAL MULTI-PROTOCOL REPLICATION)\n# Native Single-Binary Edition (Windows / Linux)\n# ====================================================================\n\n")
	content := append(header, data...)

	if err := os.WriteFile(path, content, 0644); err != nil {
		return fmt.Errorf("failed writing config file: %w", err)
	}

	return nil
}

// Validate checks for logical consistency and invalid parameter values.
func (c *Config) Validate() error {
	dirLower := strings.ToLower(string(c.SyncDirection))
	switch dirLower {
	case "push":
		c.SyncDirection = DirectionPush
	case "pull":
		c.SyncDirection = DirectionPull
	case "local":
		c.SyncDirection = DirectionLocal
	default:
		return fmt.Errorf("invalid sync_direction %q: must be 'Push', 'Pull', or 'Local'", c.SyncDirection)
	}

	protoUpper := strings.ToUpper(string(c.Protocol))
	switch protoUpper {
	case "SFTP":
		c.Protocol = ProtocolSFTP
		if c.Endpoint.Port == 0 {
			c.Endpoint.Port = 22
		}
	case "SMB":
		c.Protocol = ProtocolSMB
		if c.Endpoint.Port == 0 {
			c.Endpoint.Port = 445
		}
	case "LOCAL":
		c.Protocol = ProtocolLocal
	default:
		return fmt.Errorf("invalid protocol %q: must be 'SFTP', 'SMB', or 'Local'", c.Protocol)
	}

	if len(c.Mappings) == 0 {
		return fmt.Errorf("at least one folder mapping must be specified")
	}

	for i, m := range c.Mappings {
		if strings.TrimSpace(m.Source) == "" {
			return fmt.Errorf("mapping[%d] %q: source path cannot be empty", i, m.Name)
		}
		if strings.TrimSpace(m.Destination) == "" {
			return fmt.Errorf("mapping[%d] %q: destination path cannot be empty", i, m.Name)
		}
		if len(m.FileTypes) == 0 {
			c.Mappings[i].FileTypes = []string{"*"}
		}
	}

	if c.Logging.LogFolder == "" {
		c.Logging.LogFolder = "./logs"
	}
	if c.Logging.MaxLogSizeMB <= 0 {
		c.Logging.MaxLogSizeMB = 10
	}
	if c.Logging.MaxArchivedLogs <= 0 {
		c.Logging.MaxArchivedLogs = 20
	}
	if c.Logging.LogRetentionDays <= 0 {
		c.Logging.LogRetentionDays = 30
	}

	if c.Scheduler.IntervalSeconds <= 0 {
		c.Scheduler.IntervalSeconds = 60
	}
	if c.Scheduler.RetryAttempts < 0 {
		c.Scheduler.RetryAttempts = 5
	}
	if c.Scheduler.RetryWaitSeconds < 0 {
		c.Scheduler.RetryWaitSeconds = 15
	}

	if c.Lifecycle.EnableSourceDelete && c.Lifecycle.SourceDeleteDays < 1 {
		return fmt.Errorf("source_delete_days must be at least 1 day when source deletion is enabled")
	}
	if c.Lifecycle.EnableDestArchiveDelete && c.Lifecycle.DestArchiveDeleteMonths < 1 {
		return fmt.Errorf("dest_archive_delete_months must be at least 1 month when archive deletion is enabled")
	}

	return nil
}

