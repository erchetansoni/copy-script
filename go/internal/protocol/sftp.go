package protocol

import (
	"fmt"
	"io"
	"net"
	"os"
	"path"
	"strings"
	"time"

	"github.com/pkg/sftp"
	"golang.org/x/crypto/ssh"
)

// SftpVFS implements VFS over an encrypted SSH/SFTP connection without invoking external processes.
type SftpVFS struct {
	sshClient  *ssh.Client
	sftpClient *sftp.Client
}

// SftpConfig holds credentials for establishing an SFTP session.
type SftpConfig struct {
	Host           string
	Port           int
	Username       string
	Password       string
	PrivateKeyPath string
	KeyPassphrase  string
	Timeout        time.Duration
}

// NewSftpVFS connects to the remote host using pure Go SSH/SFTP.
func NewSftpVFS(cfg SftpConfig) (*SftpVFS, error) {
	if cfg.Port <= 0 {
		cfg.Port = 22
	}
	if cfg.Timeout <= 0 {
		cfg.Timeout = 15 * time.Second
	}

	var authMethods []ssh.AuthMethod

	// Private key authentication
	if cfg.PrivateKeyPath != "" {
		keyBytes, err := os.ReadFile(cfg.PrivateKeyPath)
		if err != nil {
			return nil, fmt.Errorf("failed reading SSH private key from %q: %w", cfg.PrivateKeyPath, err)
		}

		var signer ssh.Signer
		if cfg.KeyPassphrase != "" {
			signer, err = ssh.ParsePrivateKeyWithPassphrase(keyBytes, []byte(cfg.KeyPassphrase))
		} else {
			signer, err = ssh.ParsePrivateKey(keyBytes)
		}
		if err != nil {
			return nil, fmt.Errorf("failed parsing SSH private key: %w", err)
		}
		authMethods = append(authMethods, ssh.PublicKeys(signer))
	}

	// Password authentication
	if cfg.Password != "" {
		authMethods = append(authMethods, ssh.Password(cfg.Password))
	}

	if len(authMethods) == 0 {
		return nil, fmt.Errorf("no authentication method provided: specify either a private key or password")
	}

	sshConfig := &ssh.ClientConfig{
		User:            cfg.Username,
		Auth:            authMethods,
		HostKeyCallback: ssh.InsecureIgnoreHostKey(), // Air-gapped / internal industrial PLC networks
		Timeout:         cfg.Timeout,
	}

	addr := net.JoinHostPort(cfg.Host, fmt.Sprintf("%d", cfg.Port))
	sshClient, err := ssh.Dial("tcp", addr, sshConfig)
	if err != nil {
		return nil, fmt.Errorf("failed establishing SSH connection to %s: %w", addr, err)
	}

	sftpClient, err := sftp.NewClient(sshClient)
	if err != nil {
		_ = sshClient.Close()
		return nil, fmt.Errorf("failed initializing SFTP subsystem on %s: %w", addr, err)
	}

	return &SftpVFS{
		sshClient:  sshClient,
		sftpClient: sftpClient,
	}, nil
}

// normalizeRemotePath converts Windows or mixed paths to POSIX SFTP paths.
func normalizeRemotePath(p string) string {
	p = strings.TrimSpace(p)
	p = strings.ReplaceAll(p, "\\", "/")

	// Strip leading IP or UNC prefix if accidentally passed (e.g. //10.91.13.204/share)
	if strings.HasPrefix(p, "//") {
		parts := strings.SplitN(p[2:], "/", 2)
		if len(parts) == 2 {
			p = "/" + parts[1]
		}
	}

	// If path starts with a Windows drive like C:/dir, format as /C:/dir for Windows OpenSSH server
	if len(p) >= 2 && p[1] == ':' {
		p = "/" + p
	}

	if !strings.HasPrefix(p, "/") {
		p = "/" + p
	}
	return path.Clean(p)
}

// ListFiles returns files in the remote directory matching patterns.
func (v *SftpVFS) ListFiles(dir string, patterns []string) ([]FileInfo, error) {
	normDir := normalizeRemotePath(dir)
	entries, err := v.sftpClient.ReadDir(normDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed reading remote directory %q: %w", normDir, err)
	}

	var results []FileInfo
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() {
			continue
		}
		if !MatchesAnyGlob(name, patterns) {
			continue
		}

		results = append(results, FileInfo{
			Name:    name,
			Path:    path.Join(normDir, name),
			Size:    entry.Size(),
			ModTime: entry.ModTime(),
			IsDir:   false,
		})
	}

	return results, nil
}

// ListDirs returns subdirectories in the remote directory.
func (v *SftpVFS) ListDirs(dir string) ([]FileInfo, error) {
	normDir := normalizeRemotePath(dir)
	entries, err := v.sftpClient.ReadDir(normDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed reading remote directory %q: %w", normDir, err)
	}

	var results []FileInfo
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		results = append(results, FileInfo{
			Name:    entry.Name(),
			Path:    path.Join(normDir, entry.Name()),
			Size:    0,
			ModTime: entry.ModTime(),
			IsDir:   true,
		})
	}
	return results, nil
}

// Stat returns metadata for a remote path.
func (v *SftpVFS) Stat(p string) (*FileInfo, error) {
	norm := normalizeRemotePath(p)
	fi, err := v.sftpClient.Stat(norm)
	if err != nil {
		return nil, err
	}
	return &FileInfo{
		Name:    fi.Name(),
		Path:    norm,
		Size:    fi.Size(),
		ModTime: fi.ModTime(),
		IsDir:   fi.IsDir(),
	}, nil
}

// OpenRead opens a remote file for streaming.
func (v *SftpVFS) OpenRead(p string) (io.ReadCloser, error) {
	norm := normalizeRemotePath(p)
	return v.sftpClient.Open(norm)
}

// WriteAtomic streams to a remote temporary file, updates timestamp, and renames.
func (v *SftpVFS) WriteAtomic(p string, r io.Reader, modTime time.Time) (int64, error) {
	norm := normalizeRemotePath(p)
	dir := path.Dir(norm)

	if err := v.EnsureDir(dir); err != nil {
		return 0, fmt.Errorf("failed creating remote directory %q: %w", dir, err)
	}

	tmpPath := fmt.Sprintf("%s.%d.tmp", norm, time.Now().UnixNano())
	tmpFile, err := v.sftpClient.OpenFile(tmpPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		return 0, fmt.Errorf("failed creating remote temporary file %q: %w", tmpPath, err)
	}

	buf := make([]byte, 64*1024)
	written, err := io.CopyBuffer(tmpFile, r, buf)
	if err != nil {
		_ = tmpFile.Close()
		_ = v.sftpClient.Remove(tmpPath)
		return 0, fmt.Errorf("failed writing to remote temporary file: %w", err)
	}
	_ = tmpFile.Close()

	if !modTime.IsZero() {
		_ = v.sftpClient.Chtimes(tmpPath, modTime, modTime)
	}

	// Remove target if it already exists before renaming
	_ = v.sftpClient.Remove(norm)
	if err := v.sftpClient.Rename(tmpPath, norm); err != nil {
		_ = v.sftpClient.Remove(tmpPath)
		return 0, fmt.Errorf("failed renaming remote temporary file to %q: %w", norm, err)
	}

	if !modTime.IsZero() {
		_ = v.sftpClient.Chtimes(norm, modTime, modTime)
	}

	return written, nil
}

// EnsureDir recursively creates the remote directory hierarchy.
func (v *SftpVFS) EnsureDir(p string) error {
	norm := normalizeRemotePath(p)
	return v.sftpClient.MkdirAll(norm)
}

// Move renames or moves a remote file.
func (v *SftpVFS) Move(oldPath, newPath string) error {
	normOld := normalizeRemotePath(oldPath)
	normNew := normalizeRemotePath(newPath)

	dir := path.Dir(normNew)
	if err := v.EnsureDir(dir); err != nil {
		return err
	}
	_ = v.sftpClient.Remove(normNew)
	return v.sftpClient.Rename(normOld, normNew)
}

// Remove deletes a remote file.
func (v *SftpVFS) Remove(p string) error {
	norm := normalizeRemotePath(p)
	return v.sftpClient.Remove(norm)
}

// RemoveAll deletes a remote path and all children recursively.
func (v *SftpVFS) RemoveAll(p string) error {
	norm := normalizeRemotePath(p)
	// Walk and delete
	walker := v.sftpClient.Walk(norm)
	var paths []string
	for walker.Step() {
		if walker.Err() != nil {
			continue
		}
		paths = append(paths, walker.Path())
	}
	// Delete in reverse order (children first)
	for i := len(paths) - 1; i >= 0; i-- {
		_ = v.sftpClient.Remove(paths[i])
	}
	return v.sftpClient.RemoveDirectory(norm)
}

// Close disconnects SFTP and SSH sessions cleanly.
func (v *SftpVFS) Close() error {
	var errs []string
	if v.sftpClient != nil {
		if err := v.sftpClient.Close(); err != nil {
			errs = append(errs, err.Error())
		}
	}
	if v.sshClient != nil {
		if err := v.sshClient.Close(); err != nil {
			errs = append(errs, err.Error())
		}
	}
	if len(errs) > 0 {
		return fmt.Errorf("errors closing SFTP session: %s", strings.Join(errs, "; "))
	}
	return nil
}

