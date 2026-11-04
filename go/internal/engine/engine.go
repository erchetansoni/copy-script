package engine

import (
	"context"
	"time"

	"copymaster/internal/config"
	"copymaster/internal/logger"
	"copymaster/internal/protocol"
)

// Engine orchestrates multi-folder synchronization cycles, logging, and daemon scheduling.
type Engine struct {
	cfg *config.Config
	log *logger.Logger
}

// NewEngine creates an initialized Engine instance.
func NewEngine(cfg *config.Config, log *logger.Logger) *Engine {
	return &Engine{
		cfg: cfg,
		log: log,
	}
}

// RunCycle executes one complete replication cycle across all configured folder mappings.
func (e *Engine) RunCycle() (int, int, int) {
	startTime := time.Now()
	e.log.Log(logger.LevelInfo, "======================================================================")
	e.log.Log(logger.LevelInfo, "Replication Cycle Started (%s | Direction: %s)", e.cfg.Protocol, e.cfg.SyncDirection)
	e.log.Log(logger.LevelInfo, "======================================================================")

	localFS := protocol.NewLocalVFS()
	defer localFS.Close()

	var remoteFS protocol.VFS
	if e.cfg.Protocol == config.ProtocolSFTP {
		if e.cfg.Endpoint.Host == "" {
			e.log.Log(logger.LevelWarn, "Remote SFTP host is not configured. Please specify remote host in config.yaml or via Web Dashboard.")
			return 0, 0, len(e.cfg.Mappings)
		}

		sftpCfg := protocol.SftpConfig{
			Host:           e.cfg.Endpoint.Host,
			Port:           e.cfg.Endpoint.Port,
			Username:       e.cfg.Endpoint.Username,
			Password:       e.cfg.Endpoint.Password,
			PrivateKeyPath: e.cfg.Endpoint.PrivateKeyPath,
			KeyPassphrase:  e.cfg.Endpoint.KeyPassphrase,
			Timeout:        15 * time.Second,
		}

		sftpFS, err := protocol.NewSftpVFS(sftpCfg)
		if err != nil {
			e.log.Log(logger.LevelError, "Failed establishing SFTP connection to %s:%d: %v",
				e.cfg.Endpoint.Host, e.cfg.Endpoint.Port, err)
			return 0, len(e.cfg.Mappings), 0
		}
		defer sftpFS.Close()
		remoteFS = sftpFS
		e.log.Log(logger.LevelSuccess, "Connected to remote SFTP host %s:%d", e.cfg.Endpoint.Host, e.cfg.Endpoint.Port)
	}

	totalCopied := 0
	totalFailed := 0
	totalSkipped := 0
	var totalBytes int64 = 0

	for _, mapping := range e.cfg.Mappings {
		res := SyncMapping(mapping, e.cfg, localFS, remoteFS, e.log)
		totalCopied += res.Copied
		totalFailed += res.Failed
		totalSkipped += res.Skipped
		totalBytes += res.BytesCopied
	}

	elapsed := time.Since(startTime)
	e.log.Log(logger.LevelSuccess, "Replication Cycle Finished in %v: %d copied (%s), %d skipped, %d failed.",
		elapsed.Round(time.Millisecond), totalCopied, formatBytes(totalBytes), totalSkipped, totalFailed)

	return totalCopied, totalFailed, totalSkipped
}

// RunDaemon runs continuous replication cycles until the context is canceled.
func (e *Engine) RunDaemon(ctx context.Context) {
	interval := time.Duration(e.cfg.Scheduler.IntervalSeconds) * time.Second
	e.log.Log(logger.LevelInfo, "Copy Master Daemon active. Replication interval: %v", interval)

	// Run first cycle immediately
	e.RunCycle()

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			e.log.Log(logger.LevelInfo, "Shutdown requested. Stopping replication daemon gracefully...")
			return
		case <-ticker.C:
			e.RunCycle()
		}
	}
}
