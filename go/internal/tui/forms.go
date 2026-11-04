package tui

import (
	"strconv"
	"strings"

	"copymaster/internal/config"

	"github.com/charmbracelet/huh"
)

// EndpointFormData holds the bound values for the endpoint configuration form.
type EndpointFormData struct {
	Protocol       string
	SyncDirection  string
	Host           string
	Port           string
	Username       string
	Password       string
	PrivateKeyPath string
}

// NewEndpointForm creates an interactive Huh form for protocol and remote credentials.
func NewEndpointForm(cfg *config.Config, data *EndpointFormData) *huh.Form {
	data.Protocol = string(cfg.Protocol)
	data.SyncDirection = string(cfg.SyncDirection)
	data.Host = cfg.Endpoint.Host
	data.Port = strconv.Itoa(cfg.Endpoint.Port)
	data.Username = cfg.Endpoint.Username
	data.Password = cfg.Endpoint.Password
	data.PrivateKeyPath = cfg.Endpoint.PrivateKeyPath

	protoOptions := []huh.Option[string]{
		huh.NewOption("SFTP   - SSH File Transfer Protocol (Port 22)", "SFTP"),
		huh.NewOption("SCP    - Secure Copy Protocol via SSH (Port 22)", "SCP"),
		huh.NewOption("SMB    - Windows Network Share / CIFS (Port 445)", "SMB"),
		huh.NewOption("FTPS   - FTP over Explicit TLS/SSL (Port 990)", "FTPS"),
		huh.NewOption("FTP    - Standard File Transfer Protocol (Port 21)", "FTP"),
		huh.NewOption("WebDAV - HTTP/HTTPS Web Distributed Authoring (Port 443)", "WebDAV"),
		huh.NewOption("Local  - Local Disk / Native Mounted Path", "Local"),
	}

	dirOptions := []huh.Option[string]{
		huh.NewOption("Push  - Local Source -> Remote Destination (Upload)", "Push"),
		huh.NewOption("Pull  - Remote Source -> Local Destination (Download)", "Pull"),
		huh.NewOption("Local - Local Source -> Local Destination (Local / UNC)", "Local"),
	}

	return huh.NewForm(
		huh.NewGroup(
			huh.NewSelect[string]().
				Title("Transfer Protocol").
				Description("Choose the replication protocol for network transfers").
				Options(protoOptions...).
				Value(&data.Protocol),

			huh.NewSelect[string]().
				Title("Sync Direction").
				Description("Push uploads from local source; Pull downloads from remote").
				Options(dirOptions...).
				Value(&data.SyncDirection),
		),
		huh.NewGroup(
			huh.NewInput().
				Title("Remote Host / IP Address").
				Description("Hostname, FQDN or IP of remote endpoint (e.g. 172.20.64.12)").
				Value(&data.Host),

			huh.NewInput().
				Title("Port").
				Description("Port number (Default: 22 for SFTP/SCP, 445 for SMB, 990 for FTPS)").
				Value(&data.Port),

			huh.NewInput().
				Title("Username").
				Description("Authentication username or domain\\user").
				Value(&data.Username),

			huh.NewInput().
				Title("Password / Secret").
				Description("Account password or private key passphrase").
				EchoMode(huh.EchoModePassword).
				Value(&data.Password),

			huh.NewInput().
				Title("SSH Private Key Path").
				Description("Path to Ed25519 or RSA private key (e.g. ~/.ssh/id_ed25519)").
				Value(&data.PrivateKeyPath),
		),
	).WithTheme(huh.ThemeCharm())
}

// MappingFormData holds input for adding a folder mapping.
type MappingFormData struct {
	Name        string
	Source      string
	Destination string
	FileTypes   string
}

// NewAddMappingForm creates an interactive Huh form to define a new folder mapping.
func NewAddMappingForm(data *MappingFormData) *huh.Form {
	data.Name = "Line 1"
	data.Source = "C:\\temp\\TEST\\data1"
	data.Destination = "C:\\ot_share\\test1"
	data.FileTypes = "*.csv, *.*"

	return huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Mapping Name").
				Description("Descriptive label for this replication pair").
				Value(&data.Name),

			huh.NewInput().
				Title("Source Path").
				Description("Local directory or remote source path").
				Value(&data.Source),

			huh.NewInput().
				Title("Destination Path").
				Description("Target destination directory or server path").
				Value(&data.Destination),

			huh.NewInput().
				Title("File Types Filter").
				Description("Comma-separated patterns (e.g. *.csv, *.dat, *.*)").
				Value(&data.FileTypes),
		),
	).WithTheme(huh.ThemeCharm())
}

// PolicyFormData holds policy and scheduling parameters.
type PolicyFormData struct {
	EnableSourceDelete       bool
	SourceDeleteDays         string
	EnableDestMonthlyArchive bool
	EnableDestArchiveDelete  bool
	DestArchiveDeleteMonths  string
	IntervalSeconds          string
	LogFolder                string
	MaxLogSizeMB             string
	LogRetentionDays         string
}

// NewPolicyForm creates an interactive Huh form for data lifecycle and daemon policies.
func NewPolicyForm(cfg *config.Config, data *PolicyFormData) *huh.Form {
	data.EnableSourceDelete = cfg.Lifecycle.EnableSourceDelete
	data.SourceDeleteDays = strconv.Itoa(cfg.Lifecycle.SourceDeleteDays)
	data.EnableDestMonthlyArchive = cfg.Lifecycle.EnableDestMonthlyArchive
	data.EnableDestArchiveDelete = cfg.Lifecycle.EnableDestArchiveDelete
	data.DestArchiveDeleteMonths = strconv.Itoa(cfg.Lifecycle.DestArchiveDeleteMonths)
	data.IntervalSeconds = strconv.Itoa(cfg.Scheduler.IntervalSeconds)
	data.LogFolder = cfg.Logging.LogFolder
	data.MaxLogSizeMB = strconv.Itoa(cfg.Logging.MaxLogSizeMB)
	data.LogRetentionDays = strconv.Itoa(cfg.Logging.LogRetentionDays)

	return huh.NewForm(
		huh.NewGroup(
			huh.NewConfirm().
				Title("Enable Verified Source Cleanup").
				Description("Safely deletes source files older than threshold ONLY after destination byte verification").
				Value(&data.EnableSourceDelete),

			huh.NewInput().
				Title("Source File Age Threshold (Days)").
				Description("Delete verified source files older than this many days").
				Value(&data.SourceDeleteDays),

			huh.NewConfirm().
				Title("Enable Monthly Archiving (YYYY-MM)").
				Description("Automatically organizes previous months' files into YYYY-MM subfolders").
				Value(&data.EnableDestMonthlyArchive),

			huh.NewConfirm().
				Title("Enable Destination Archive Purge").
				Description("Permanently prunes historical YYYY-MM archive folders exceeding retention age").
				Value(&data.EnableDestArchiveDelete),

			huh.NewInput().
				Title("Archive Purge Threshold (Months)").
				Description("Delete YYYY-MM folders older than this many months").
				Value(&data.DestArchiveDeleteMonths),
		),
		huh.NewGroup(
			huh.NewInput().
				Title("Daemon Replication Interval (Seconds)").
				Description("Frequency of replication cycles in continuous daemon mode").
				Value(&data.IntervalSeconds),

			huh.NewInput().
				Title("Log Directory").
				Description("Directory where dual operational and detail logs are stored").
				Value(&data.LogFolder),

			huh.NewInput().
				Title("Max Log Size (MB)").
				Description("Size threshold before rotating log file into compressed archive").
				Value(&data.MaxLogSizeMB),

			huh.NewInput().
				Title("Log Retention (Days)").
				Description("Days to retain rotated log archives before cleanup").
				Value(&data.LogRetentionDays),
		),
	).WithTheme(huh.ThemeCharm())
}

// SSHWizardFormData holds data for generating an air-gapped SSH key.
type SSHWizardFormData struct {
	SavePath string
	Comment  string
}

// NewSSHWizardForm creates an interactive Huh form for generating and saving an Ed25519 key pair.
func NewSSHWizardForm(defaultPath string, data *SSHWizardFormData) *huh.Form {
	data.SavePath = defaultPath
	data.Comment = "copymaster@airgap"

	return huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Private Key Destination File").
				Description("File path where the Ed25519 private key will be saved (0600 permissions)").
				Value(&data.SavePath),

			huh.NewInput().
				Title("Key Comment / Identifier").
				Description("Comment appended to public key (e.g. copymaster@plant-node)").
				Value(&data.Comment),
		),
	).WithTheme(huh.ThemeCharm())
}

// OpenFileFormData holds data for opening / importing a config or script.
type OpenFileFormData struct {
	FilePath string
}

// NewOpenFileForm creates an interactive Huh form to specify a YAML or .ps1 file to import.
func NewOpenFileForm(currentPath string, data *OpenFileFormData) *huh.Form {
	data.FilePath = currentPath

	return huh.NewForm(
		huh.NewGroup(
			huh.NewInput().
				Title("Configuration / Script Path").
				Description("Enter path to config.yaml or existing CopyMaster PowerShell script (.ps1)").
				Value(&data.FilePath),
		),
	).WithTheme(huh.ThemeCharm())
}

// ApplyEndpointData updates the active config from the submitted form.
func ApplyEndpointData(cfg *config.Config, data *EndpointFormData) {
	cfg.Protocol = config.Protocol(data.Protocol)
	cfg.SyncDirection = config.SyncDirection(data.SyncDirection)
	cfg.Endpoint.Host = strings.TrimSpace(data.Host)
	if p, err := strconv.Atoi(strings.TrimSpace(data.Port)); err == nil && p > 0 {
		cfg.Endpoint.Port = p
	}
	cfg.Endpoint.Username = strings.TrimSpace(data.Username)
	cfg.Endpoint.Password = data.Password
	cfg.Endpoint.PrivateKeyPath = strings.TrimSpace(data.PrivateKeyPath)
}

// ApplyPolicyData updates the active config from the submitted form.
func ApplyPolicyData(cfg *config.Config, data *PolicyFormData) {
	cfg.Lifecycle.EnableSourceDelete = data.EnableSourceDelete
	if d, err := strconv.Atoi(strings.TrimSpace(data.SourceDeleteDays)); err == nil {
		cfg.Lifecycle.SourceDeleteDays = d
	}
	cfg.Lifecycle.EnableDestMonthlyArchive = data.EnableDestMonthlyArchive
	cfg.Lifecycle.EnableDestArchiveDelete = data.EnableDestArchiveDelete
	if m, err := strconv.Atoi(strings.TrimSpace(data.DestArchiveDeleteMonths)); err == nil {
		cfg.Lifecycle.DestArchiveDeleteMonths = m
	}
	if s, err := strconv.Atoi(strings.TrimSpace(data.IntervalSeconds)); err == nil && s > 0 {
		cfg.Scheduler.IntervalSeconds = s
	}
	cfg.Logging.LogFolder = strings.TrimSpace(data.LogFolder)
	if sz, err := strconv.Atoi(strings.TrimSpace(data.MaxLogSizeMB)); err == nil && sz > 0 {
		cfg.Logging.MaxLogSizeMB = sz
	}
	if r, err := strconv.Atoi(strings.TrimSpace(data.LogRetentionDays)); err == nil && r > 0 {
		cfg.Logging.LogRetentionDays = r
	}
}

