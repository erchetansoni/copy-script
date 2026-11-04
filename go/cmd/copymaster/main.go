package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	"copymaster/internal/config"
	"copymaster/internal/engine"
	"copymaster/internal/logger"
	"copymaster/internal/protocol"
	"copymaster/internal/tui"
)

var (
	Version   = "2.0.0"
	BuildDate = "2026-11-04"
	GitCommit = "release"
)

func main() {
	var (
		configPath string
		initConfig string
		runOnce    bool
		daemonMode bool
		testMode   bool
		showVer    bool
	)

	flag.StringVar(&configPath, "config", "", "Path to YAML or .ps1 configuration file")
	flag.StringVar(&configPath, "c", "", "Path to YAML or .ps1 configuration file (shorthand)")
	flag.StringVar(&initConfig, "init-config", "", "Generate a documented sample configuration file at the specified path and exit")
	flag.BoolVar(&runOnce, "once", false, "Execute a single replication cycle and exit immediately (headless)")
	flag.BoolVar(&runOnce, "run-once", false, "Execute a single replication cycle and exit immediately (headless)")
	flag.BoolVar(&daemonMode, "daemon", false, "Run in headless background daemon mode (no UI)")
	flag.BoolVar(&testMode, "test", false, "Validate configuration and test endpoint connectivity without replicating")
	flag.BoolVar(&showVer, "version", false, "Print application version, OS/Arch, and runtime info")
	flag.BoolVar(&showVer, "v", false, "Print application version (shorthand)")

	flag.Usage = func() {
		fmt.Printf("Copy Master - Industrial Multi-Protocol Replication Suite (v%s)\n", Version)
		fmt.Printf("Cross-Platform Native Standalone Agent (OS: %s, Arch: %s)\n\n", runtime.GOOS, runtime.GOARCH)
		fmt.Println("Usage:")
		fmt.Println("  copymaster [options]")
		fmt.Println("\nOptions:")
		flag.PrintDefaults()
		fmt.Println("\nInteractive / Air-Gapped Terminal UI:")
		fmt.Println("  copymaster                             # Launch full air-gapped Terminal UI (TUI)")
		fmt.Println("  copymaster -config config.yaml         # Launch TUI with custom configuration")
		fmt.Println("\nHeadless Automation (Scheduled Tasks / Cron / systemd):")
		fmt.Println("  copymaster -config config.yaml -once   # Run a single headless replication cycle and exit")
		fmt.Println("  copymaster -config config.yaml -daemon # Run continuously in background")
		fmt.Println("  copymaster -config config.yaml -test   # Test connectivity to endpoints and exit")
		fmt.Println("  copymaster -init-config config.yaml    # Generate sample configuration")
	}

	flag.Parse()

	if showVer {
		fmt.Printf("Copy Master v%s (%s/%s)\n", Version, runtime.GOOS, runtime.GOARCH)
		fmt.Printf("Build Date : %s\n", BuildDate)
		fmt.Printf("Git Commit : %s\n", GitCommit)
		fmt.Printf("Go Runtime : %s\n", runtime.Version())
		pauseIfDoubleClicked()
		os.Exit(0)
	}

	if initConfig != "" {
		cfg := config.DefaultConfig()
		if err := cfg.Save(initConfig); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing configuration template: %v\n", err)
			pauseIfDoubleClicked()
			os.Exit(1)
		}
		fmt.Printf("Successfully generated configuration template at: %s\n", initConfig)
		pauseIfDoubleClicked()
		os.Exit(0)
	}

	// Locate or automatically generate config file
	exePath, _ := os.Executable()
	exeDir := filepath.Dir(exePath)

	resolvedConfig := configPath
	if resolvedConfig == "" {
		// Check candidates in current working dir and executable directory
		candidates := []string{
			"config.yaml",
			"copymaster.yaml",
			filepath.Join(exeDir, "config.yaml"),
			filepath.Join(exeDir, "copymaster.yaml"),
		}
		for _, cand := range candidates {
			if _, err := os.Stat(cand); err == nil {
				resolvedConfig = cand
				break
			}
		}

		// If still not found, auto-generate config.yaml in executable directory!
		if resolvedConfig == "" {
			targetAuto := filepath.Join(exeDir, "config.yaml")
			defaultCfg := config.DefaultConfig()
			_ = defaultCfg.Save(targetAuto)
			resolvedConfig = targetAuto
		}
	}

	cfg, err := tui.LoadFromFile(resolvedConfig)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Configuration Error: %v\n\n", err)
		fmt.Fprintf(os.Stderr, "Tip: Run 'copymaster -init-config %s' to generate a valid template.\n", resolvedConfig)
		pauseIfDoubleClicked()
		os.Exit(1)
	}

	log, err := logger.New(cfg.Logging)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Logger Initialization Error: %v\n", err)
		pauseIfDoubleClicked()
		os.Exit(1)
	}
	defer log.Close()

	if testMode {
		runConnectivityTest(cfg, log)
		pauseIfDoubleClicked()
		os.Exit(0)
	}

	eng := engine.NewEngine(cfg, log)

	// Headless one-shot mode (Windows Task Scheduler / Linux Cron)
	if runOnce || cfg.Scheduler.RunOnce {
		log.Log(logger.LevelInfo, "Copy Master running in headless one-shot mode (-once)")
		_, failed, _ := eng.RunCycle()
		if failed > 0 {
			pauseIfDoubleClicked()
			os.Exit(1)
		}
		pauseIfDoubleClicked()
		os.Exit(0)
	}

	// Headless daemon mode
	if daemonMode {
		log.Log(logger.LevelInfo, "Copy Master running in headless background daemon mode (-daemon)")
		ctx, cancel := context.WithCancel(context.Background())
		sigChan := make(chan os.Signal, 1)
		signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

		go func() {
			sig := <-sigChan
			log.Log(logger.LevelWarn, "Received system signal %s. Shutting down daemon gracefully...", sig)
			cancel()
		}()

		eng.RunDaemon(ctx)
		return
	}

	// Interactive Terminal UI (TUI) Mode: Default for console/double-click
	if err := tui.Run(cfg, resolvedConfig, eng, log); err != nil {
		fmt.Fprintf(os.Stderr, "Error running TUI: %v\n", err)
		pauseIfDoubleClicked()
		os.Exit(1)
	}
}

func runConnectivityTest(cfg *config.Config, log *logger.Logger) {
	log.Log(logger.LevelInfo, "Testing connectivity for protocol: %s (Direction: %s)...", cfg.Protocol, cfg.SyncDirection)

	switch cfg.Protocol {
	case config.ProtocolSFTP:
		log.Log(logger.LevelInfo, "Connecting to SFTP server %s:%d as %q...",
			cfg.Endpoint.Host, cfg.Endpoint.Port, cfg.Endpoint.Username)
		sftpCfg := protocol.SftpConfig{
			Host:           cfg.Endpoint.Host,
			Port:           cfg.Endpoint.Port,
			Username:       cfg.Endpoint.Username,
			Password:       cfg.Endpoint.Password,
			PrivateKeyPath: cfg.Endpoint.PrivateKeyPath,
			KeyPassphrase:  cfg.Endpoint.KeyPassphrase,
			Timeout:        10 * time.Second,
		}
		sftpFS, err := protocol.NewSftpVFS(sftpCfg)
		if err != nil {
			log.Log(logger.LevelError, "SFTP Connection FAILED: %v", err)
			return
		}
		_ = sftpFS.Close()
		log.Log(logger.LevelSuccess, "SFTP Connection & Authentication SUCCEEDED!")

	case config.ProtocolLocal, config.ProtocolSMB:
		localFS := protocol.NewLocalVFS()
		for _, m := range cfg.Mappings {
			log.Log(logger.LevelInfo, "Verifying mapping paths for [%s]...", m.Name)
			if fi, err := localFS.Stat(m.Source); err != nil {
				log.Log(logger.LevelWarn, "Source path %q not accessible or not created yet: %v", m.Source, err)
			} else {
				log.Log(logger.LevelSuccess, "Source path %q exists (IsDir: %v)", m.Source, fi.IsDir)
			}
			if fi, err := localFS.Stat(m.Destination); err != nil {
				log.Log(logger.LevelWarn, "Destination path %q not accessible or not created yet: %v", m.Destination, err)
			} else {
				log.Log(logger.LevelSuccess, "Destination path %q exists (IsDir: %v)", m.Destination, fi.IsDir)
			}
		}
	}

	log.Log(logger.LevelSuccess, "All configured checks completed.")
}
