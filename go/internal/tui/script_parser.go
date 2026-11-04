package tui

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"copymaster/internal/config"
)

// LoadFromFile loads configuration from a YAML file or imports from an existing PowerShell replication script.
func LoadFromFile(filePath string) (*config.Config, error) {
	ext := strings.ToLower(filepath.Ext(filePath))
	if ext == ".yaml" || ext == ".yml" {
		return config.Load(filePath)
	}

	if ext == ".ps1" {
		return ImportFromPowerShell(filePath)
	}

	// Try YAML first, then PowerShell
	if cfg, err := config.Load(filePath); err == nil {
		return cfg, nil
	}
	return ImportFromPowerShell(filePath)
}

// ImportFromPowerShell parses configuration variables from an existing Copy Master PowerShell script.
func ImportFromPowerShell(filePath string) (*config.Config, error) {
	contentBytes, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed reading script file: %w", err)
	}
	text := string(contentBytes)

	cfg := config.DefaultConfig()

	// Direction
	if m := regexp.MustCompile(`(?i)\$SyncDirection\s*=\s*["']([^"']+)["']`).FindStringSubmatch(text); len(m) > 1 {
		val := strings.TrimSpace(m[1])
		if strings.EqualFold(val, "Push") {
			cfg.SyncDirection = config.DirectionPush
		} else if strings.EqualFold(val, "Pull") {
			cfg.SyncDirection = config.DirectionPull
		} else {
			cfg.SyncDirection = config.DirectionLocal
		}
	}

	// Protocol
	if m := regexp.MustCompile(`(?i)\$SourceProtocol\s*=\s*["']([^"']+)["']`).FindStringSubmatch(text); len(m) > 1 {
		val := strings.TrimSpace(m[1])
		cfg.Protocol = config.Protocol(val)
	}

	// Host
	if m := regexp.MustCompile(`(?i)\$RemoteHost\s*=\s*["']([^"']+)["']`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Endpoint.Host = strings.TrimSpace(m[1])
	}

	// Port
	if m := regexp.MustCompile(`(?i)\$RemotePort\s*=\s*(\d+)`).FindStringSubmatch(text); len(m) > 1 {
		if p, err := strconv.Atoi(m[1]); err == nil {
			cfg.Endpoint.Port = p
		}
	}

	// Username
	if m := regexp.MustCompile(`(?i)\$RemoteUsername\s*=\s*["']([^"']+)["']`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Endpoint.Username = strings.TrimSpace(m[1])
	}

	// Password
	if m := regexp.MustCompile(`(?i)\$RemotePassword\s*=\s*["']([^"']+)["']`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Endpoint.Password = strings.TrimSpace(m[1])
	}

	// SSH Key Path
	if m := regexp.MustCompile(`(?i)\$SshPrivateKeyPath\s*=\s*["']([^"']+)["']`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Endpoint.PrivateKeyPath = strings.TrimSpace(m[1])
	}

	// Lifecycle
	if m := regexp.MustCompile(`(?i)\$EnableSourceDelete\s*=\s*\$([a-zA-Z]+)`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Lifecycle.EnableSourceDelete = strings.EqualFold(m[1], "true")
	}
	if m := regexp.MustCompile(`(?i)\$SourceDeleteDays\s*=\s*(\d+)`).FindStringSubmatch(text); len(m) > 1 {
		if d, err := strconv.Atoi(m[1]); err == nil {
			cfg.Lifecycle.SourceDeleteDays = d
		}
	}
	if m := regexp.MustCompile(`(?i)\$EnableDestMonthlyArchive\s*=\s*\$([a-zA-Z]+)`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Lifecycle.EnableDestMonthlyArchive = strings.EqualFold(m[1], "true")
	}
	if m := regexp.MustCompile(`(?i)\$EnableDestArchiveDelete\s*=\s*\$([a-zA-Z]+)`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Lifecycle.EnableDestArchiveDelete = strings.EqualFold(m[1], "true")
	}
	if m := regexp.MustCompile(`(?i)\$DestArchiveDeleteMonths\s*=\s*(\d+)`).FindStringSubmatch(text); len(m) > 1 {
		if mo, err := strconv.Atoi(m[1]); err == nil {
			cfg.Lifecycle.DestArchiveDeleteMonths = mo
		}
	}

	// Logging
	if m := regexp.MustCompile(`(?i)\$LogFolder\s*=\s*["']([^"']+)["']`).FindStringSubmatch(text); len(m) > 1 {
		cfg.Logging.LogFolder = strings.TrimSpace(m[1])
	}
	if m := regexp.MustCompile(`(?i)\$MaxLogSizeMB\s*=\s*(\d+)`).FindStringSubmatch(text); len(m) > 1 {
		if s, err := strconv.Atoi(m[1]); err == nil {
			cfg.Logging.MaxLogSizeMB = s
		}
	}
	if m := regexp.MustCompile(`(?i)\$LogRetentionDays\s*=\s*(\d+)`).FindStringSubmatch(text); len(m) > 1 {
		if r, err := strconv.Atoi(m[1]); err == nil {
			cfg.Logging.LogRetentionDays = r
		}
	}

	// Parse mappings if present
	// Matches hashtables: @{ Name = "Line 1"; Source = "..."; Destination = "..."; Types = "*.csv" }
	mappingRe := regexp.MustCompile(`(?s)@\{[^}]*Name\s*=\s*["']([^"']+)["'][^}]*Source\s*=\s*["']([^"']+)["'][^}]*Destination\s*=\s*["']([^"']+)["'][^}]*\}`)
	matches := mappingRe.FindAllStringSubmatch(text, -1)
	if len(matches) > 0 {
		var mappings []config.FolderMapping
		for _, match := range matches {
			block := match[0]
			name := match[1]
			src := match[2]
			dst := match[3]
			types := []string{"*.*"}
			if tm := regexp.MustCompile(`(?i)Types\s*=\s*["']([^"']+)["']`).FindStringSubmatch(block); len(tm) > 1 {
				rawTypes := strings.Split(tm[1], ",")
				types = make([]string, 0, len(rawTypes))
				for _, t := range rawTypes {
					tr := strings.TrimSpace(t)
					if tr != "" {
						types = append(types, tr)
					}
				}
			}
			mappings = append(mappings, config.FolderMapping{
				Name:        name,
				Source:      src,
				Destination: dst,
				FileTypes:   types,
				Enabled:     true,
			})
		}
		if len(mappings) > 0 {
			cfg.Mappings = mappings
		}
	}

	return cfg, nil
}

