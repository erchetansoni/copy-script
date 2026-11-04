package tui

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"copymaster/internal/config"
	"copymaster/internal/engine"
	"copymaster/internal/logger"
	"copymaster/internal/protocol"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"
)

// Tab denotes the currently selected view.
type Tab int

const (
	TabDashboard Tab = iota
	TabEndpoint
	TabMappings
	TabPolicies
	TabSSHWizard
	TabGuide
)

// LogLineMsg is sent asynchronously when a log message is written.
type LogLineMsg struct {
	Level     logger.Level
	Timestamp string
	Message   string
}

// SyncResultMsg is sent when a background sync finishes.
type SyncResultMsg struct {
	Copied  int
	Failed  int
	Skipped int
	Elapsed time.Duration
}

// TestConnResultMsg is sent when an endpoint connectivity test finishes.
type TestConnResultMsg struct {
	Success bool
	Message string
}

// Global program reference for thread-safe event dispatching.
var (
	activeProgram *tea.Program
	progMu        sync.Mutex
)

// AppModel implements tea.Model for Copy Master.
type AppModel struct {
	cfg            *config.Config
	configPath     string
	eng            *engine.Engine
	log            *logger.Logger
	activeTab      Tab
	width          int
	height         int
	tableWidth     int
	tableHeight    int
	viewportHeight int

	// UI Components
	mappingsTable table.Model
	logViewport   viewport.Model
	guideViewport viewport.Model
	spinner       spinner.Model

	// State
	isSyncing      bool
	isTesting      bool
	statusToast    string
	toastIsError   bool
	toastExpiresAt time.Time
	logs           []string

	// Forms
	endpointForm      *huh.Form
	endpointData      EndpointFormData
	addMappingForm    *huh.Form
	mappingData       MappingFormData
	showAddMapping    bool
	policyForm        *huh.Form
	policyData        PolicyFormData
	sshWizardForm     *huh.Form
	sshWizardData     SSHWizardFormData
	generatedSSHKey   *GeneratedSSHKey
	openFileForm      *huh.Form
	openFileData      OpenFileFormData
	showOpenFileModal bool
}

// Run starts the Bubble Tea event loop with full terminal styling.
func Run(cfg *config.Config, configPath string, eng *engine.Engine, log *logger.Logger) error {
	// Silence standard console stdout so Bubble Tea controls the full terminal screen
	log.SetConsoleOutput(false)

	model := newAppModel(cfg, configPath, eng, log)

	p := tea.NewProgram(
		model,
		tea.WithAltScreen(),
		tea.WithMouseCellMotion(),
	)

	progMu.Lock()
	activeProgram = p
	progMu.Unlock()

	// Register logger listener to stream logs asynchronously into Bubble Tea via p.Send()
	log.SetListener(func(lvl logger.Level, timestamp string, msg string) {
		progMu.Lock()
		cur := activeProgram
		progMu.Unlock()

		if cur != nil {
			go cur.Send(LogLineMsg{
				Level:     lvl,
				Timestamp: timestamp,
				Message:   msg,
			})
		}
	})

	_, err := p.Run()
	return err
}

func newAppModel(cfg *config.Config, configPath string, eng *engine.Engine, log *logger.Logger) AppModel {
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(ColorSuccess)

	vp := viewport.New(100, 12)
	vp.SetContent("Copy Master Live Auditing Console initialized.\nWaiting for replication events...\n")

	gvp := viewport.New(100, 16)
	gvp.SetContent(GenerateServerGuide(string(cfg.Protocol), cfg.Endpoint.Host, cfg.Endpoint.Port, cfg.Endpoint.Username, ""))

	m := AppModel{
		cfg:            cfg,
		configPath:     configPath,
		eng:            eng,
		log:            log,
		activeTab:      TabDashboard,
		spinner:        s,
		logViewport:    vp,
		guideViewport:  gvp,
		width:          100,
		height:         30,
		tableWidth:     96,
		tableHeight:    8,
		viewportHeight: 12,
		statusToast:    "Ready (Air-Gapped Mode Active)",
		toastIsError:   false,
	}

	m.refreshMappingsTable()
	m.initForms()
	return m
}

func (m *AppModel) initForms() {
	m.endpointForm = NewEndpointForm(m.cfg, &m.endpointData)
	m.addMappingForm = NewAddMappingForm(&m.mappingData)
	m.policyForm = NewPolicyForm(m.cfg, &m.policyData)

	homeDir, _ := os.UserHomeDir()
	defaultKeyPath := filepath.Join(homeDir, ".ssh", "id_copymaster_ed25519")
	m.sshWizardForm = NewSSHWizardForm(defaultKeyPath, &m.sshWizardData)
	m.openFileForm = NewOpenFileForm(m.configPath, &m.openFileData)
}

func (m *AppModel) refreshMappingsTable() {
	columns := []table.Column{
		{Title: "#", Width: 4},
		{Title: "Name", Width: 18},
		{Title: "Source Path", Width: 32},
		{Title: "Destination Path", Width: 32},
		{Title: "File Types", Width: 14},
		{Title: "Status", Width: 10},
	}

	var rows []table.Row
	for i, mp := range m.cfg.Mappings {
		status := "Enabled"
		if !mp.Enabled {
			status = "Disabled"
		}
		types := strings.Join(mp.FileTypes, ", ")
		if types == "" {
			types = "*.*"
		}
		rows = append(rows, table.Row{
			strconv.Itoa(i + 1),
			mp.Name,
			mp.Source,
			mp.Destination,
			types,
			status,
		})
	}

	t := table.New(
		table.WithColumns(columns),
		table.WithRows(rows),
		table.WithFocused(true),
		table.WithHeight(8),
	)

	s := table.DefaultStyles()
	s.Header = s.Header.
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(ColorBorder).
		BorderBottom(true).
		Bold(true).
		Foreground(ColorPrimary)
	s.Selected = s.Selected.
		Foreground(lipgloss.Color("#ffffff")).
		Background(lipgloss.Color("#2d3555")).
		Bold(true)
	t.SetStyles(s)

	m.mappingsTable = t
}

func (m AppModel) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		m.endpointForm.Init(),
		m.policyForm.Init(),
		func() tea.Msg {
			return LogLineMsg{
				Level:     logger.LevelInfo,
				Timestamp: time.Now().Format("2006-01-02 15:04:05"),
				Message:   fmt.Sprintf("Copy Master air-gapped terminal ready. Active config: %s", m.configPath),
			}
		},
	)
}

func (m AppModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.tableWidth = max(50, msg.Width-6)
		m.tableHeight = max(5, (msg.Height-16)/2)
		m.viewportHeight = max(6, msg.Height-m.tableHeight-16)

		m.mappingsTable.SetWidth(m.tableWidth)
		m.mappingsTable.SetHeight(m.tableHeight)
		m.logViewport.Width = m.tableWidth
		m.logViewport.Height = m.viewportHeight
		m.guideViewport.Width = m.tableWidth
		m.guideViewport.Height = max(10, msg.Height-10)

	case tea.KeyMsg:
		// Global Hotkeys
		switch msg.String() {
		case "ctrl+c", "f10":
			return m, tea.Quit

		case "tab":
			if !m.showOpenFileModal && !m.showAddMapping {
				m.activeTab = (m.activeTab + 1) % 6
				m.syncTabState()
				return m, nil
			}

		case "shift+tab":
			if !m.showOpenFileModal && !m.showAddMapping {
				m.activeTab = (m.activeTab + 5) % 6
				m.syncTabState()
				return m, nil
			}

		case "1":
			if !m.isInputActive() {
				m.activeTab = TabDashboard
				return m, nil
			}
		case "2":
			if !m.isInputActive() {
				m.activeTab = TabEndpoint
				return m, nil
			}
		case "3":
			if !m.isInputActive() {
				m.activeTab = TabMappings
				return m, nil
			}
		case "4":
			if !m.isInputActive() {
				m.activeTab = TabPolicies
				return m, nil
			}
		case "5":
			if !m.isInputActive() {
				m.activeTab = TabSSHWizard
				return m, nil
			}
		case "6":
			if !m.isInputActive() {
				m.activeTab = TabGuide
				m.guideViewport.SetContent(GenerateServerGuide(string(m.cfg.Protocol), m.cfg.Endpoint.Host, m.cfg.Endpoint.Port, m.cfg.Endpoint.Username, ""))
				return m, nil
			}

		case "f2":
			// Run Sync Now
			if !m.isSyncing {
				m.isSyncing = true
				m.setToast("Starting replication cycle...", false)
				return m, m.triggerBackgroundSync()
			}

		case "f3":
			// Save Active Config
			m.saveConfig()
			return m, nil

		case "f4":
			// Test Connection
			if !m.isTesting {
				m.isTesting = true
				m.setToast("Testing connection to endpoint...", false)
				return m, m.triggerTestConnection()
			}

		case "f5":
			// Open / Import Script or YAML
			m.showOpenFileModal = !m.showOpenFileModal
			if m.showOpenFileModal {
				m.openFileForm = NewOpenFileForm(m.configPath, &m.openFileData)
				return m, m.openFileForm.Init()
			}
			return m, nil

		case "f6":
			m.activeTab = TabGuide
			m.guideViewport.SetContent(GenerateServerGuide(string(m.cfg.Protocol), m.cfg.Endpoint.Host, m.cfg.Endpoint.Port, m.cfg.Endpoint.Username, ""))
			return m, nil

		case "f7":
			m.activeTab = TabSSHWizard
			return m, nil

		case "esc":
			if m.showOpenFileModal {
				m.showOpenFileModal = false
				return m, nil
			}
			if m.showAddMapping {
				m.showAddMapping = false
				return m, nil
			}
			if m.activeTab != TabDashboard {
				m.activeTab = TabDashboard
				return m, nil
			}
		}

	case LogLineMsg:
		var prefix string
		switch msg.Level {
		case logger.LevelSuccess:
			prefix = StyleLogSuccess.Render(fmt.Sprintf("%s [SUCCESS]", msg.Timestamp))
		case logger.LevelWarn:
			prefix = StyleLogWarn.Render(fmt.Sprintf("%s [WARN]   ", msg.Timestamp))
		case logger.LevelError:
			prefix = StyleLogError.Render(fmt.Sprintf("%s [ERROR]  ", msg.Timestamp))
		default:
			prefix = StyleLogInfo.Render(fmt.Sprintf("%s [INFO]   ", msg.Timestamp))
		}
		formatted := fmt.Sprintf("%s %s", prefix, msg.Message)
		m.logs = append(m.logs, formatted)
		if len(m.logs) > 500 {
			m.logs = m.logs[len(m.logs)-500:]
		}
		m.logViewport.SetContent(strings.Join(m.logs, "\n"))
		m.logViewport.GotoBottom()
		return m, nil

	case SyncResultMsg:
		m.isSyncing = false
		if msg.Failed == 0 {
			m.setToast(fmt.Sprintf("Sync Succeeded: %d copied, %d skipped (%v)", msg.Copied, msg.Skipped, msg.Elapsed.Round(time.Millisecond)), false)
		} else {
			m.setToast(fmt.Sprintf("Sync Finished with Failures: %d failed, %d copied", msg.Failed, msg.Copied), true)
		}
		return m, nil

	case TestConnResultMsg:
		m.isTesting = false
		m.setToast(msg.Message, !msg.Success)
		return m, nil

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)
	}

	// Route updates to active forms or components
	if m.showOpenFileModal {
		form, cmd := m.openFileForm.Update(msg)
		if f, ok := form.(*huh.Form); ok {
			m.openFileForm = f
			cmds = append(cmds, cmd)
			if m.openFileForm.State == huh.StateCompleted {
				m.showOpenFileModal = false
				m.loadFile(m.openFileData.FilePath)
			}
		}
		return m, tea.Batch(cmds...)
	}

	switch m.activeTab {
	case TabDashboard:
		var cmdTable, cmdVp tea.Cmd
		m.mappingsTable, cmdTable = m.mappingsTable.Update(msg)
		m.logViewport, cmdVp = m.logViewport.Update(msg)
		cmds = append(cmds, cmdTable, cmdVp)

	case TabEndpoint:
		form, cmd := m.endpointForm.Update(msg)
		if f, ok := form.(*huh.Form); ok {
			m.endpointForm = f
			cmds = append(cmds, cmd)
			if m.endpointForm.State == huh.StateCompleted {
				ApplyEndpointData(m.cfg, &m.endpointData)
				m.setToast("Endpoint settings applied to in-memory config", false)
			}
		}

	case TabMappings:
		if m.showAddMapping {
			form, cmd := m.addMappingForm.Update(msg)
			if f, ok := form.(*huh.Form); ok {
				m.addMappingForm = f
				cmds = append(cmds, cmd)
				if m.addMappingForm.State == huh.StateCompleted {
					m.showAddMapping = false
					m.addCurrentMapping()
				}
			}
		} else {
			var cmdTable tea.Cmd
			m.mappingsTable, cmdTable = m.mappingsTable.Update(msg)
			cmds = append(cmds, cmdTable)

			// Table manipulation shortcuts in Mappings tab
			if keyMsg, ok := msg.(tea.KeyMsg); ok {
				switch keyMsg.String() {
				case "a", "+":
					m.showAddMapping = true
					m.addMappingForm = NewAddMappingForm(&m.mappingData)
					cmds = append(cmds, m.addMappingForm.Init())
				case "d", "-":
					m.removeSelectedMapping()
				case " ":
					m.toggleSelectedMapping()
				}
			}
		}

	case TabPolicies:
		form, cmd := m.policyForm.Update(msg)
		if f, ok := form.(*huh.Form); ok {
			m.policyForm = f
			cmds = append(cmds, cmd)
			if m.policyForm.State == huh.StateCompleted {
				ApplyPolicyData(m.cfg, &m.policyData)
				m.setToast("Lifecycle & Scheduling policies applied", false)
			}
		}

	case TabSSHWizard:
		form, cmd := m.sshWizardForm.Update(msg)
		if f, ok := form.(*huh.Form); ok {
			m.sshWizardForm = f
			cmds = append(cmds, cmd)
			if m.sshWizardForm.State == huh.StateCompleted {
				m.generateAndSaveSSHKey()
			}
		}

	case TabGuide:
		var cmdVp tea.Cmd
		m.guideViewport, cmdVp = m.guideViewport.Update(msg)
		cmds = append(cmds, cmdVp)
	}

	return m, tea.Batch(cmds...)
}

func (m *AppModel) syncTabState() {
	if m.activeTab == TabEndpoint {
		m.endpointForm = NewEndpointForm(m.cfg, &m.endpointData)
		_ = m.endpointForm.Init()
	} else if m.activeTab == TabPolicies {
		m.policyForm = NewPolicyForm(m.cfg, &m.policyData)
		_ = m.policyForm.Init()
	} else if m.activeTab == TabGuide {
		m.guideViewport.SetContent(GenerateServerGuide(string(m.cfg.Protocol), m.cfg.Endpoint.Host, m.cfg.Endpoint.Port, m.cfg.Endpoint.Username, ""))
	}
}

func (m *AppModel) isInputActive() bool {
	return m.activeTab == TabEndpoint || m.activeTab == TabPolicies ||
		(m.activeTab == TabMappings && m.showAddMapping) || m.showOpenFileModal
}

func (m *AppModel) setToast(msg string, isError bool) {
	m.statusToast = msg
	m.toastIsError = isError
	m.toastExpiresAt = time.Now().Add(5 * time.Second)
}

func (m *AppModel) saveConfig() {
	if m.activeTab == TabEndpoint {
		ApplyEndpointData(m.cfg, &m.endpointData)
	} else if m.activeTab == TabPolicies {
		ApplyPolicyData(m.cfg, &m.policyData)
	}

	if err := m.cfg.Validate(); err != nil {
		m.setToast(fmt.Sprintf("Validation Error: %v", err), true)
		return
	}

	if err := m.cfg.Save(m.configPath); err != nil {
		m.setToast(fmt.Sprintf("Save Failed: %v", err), true)
		m.log.Log(logger.LevelError, "Failed saving configuration: %v", err)
		return
	}

	m.setToast(fmt.Sprintf("Config saved to: %s", m.configPath), false)
	m.log.Log(logger.LevelSuccess, "Configuration saved successfully to %s", m.configPath)
}

func (m *AppModel) loadFile(path string) {
	clean := strings.TrimSpace(path)
	if clean == "" {
		m.setToast("Path cannot be empty", true)
		return
	}

	newCfg, err := LoadFromFile(clean)
	if err != nil {
		m.setToast(fmt.Sprintf("Load Failed: %v", err), true)
		m.log.Log(logger.LevelError, "Failed reading file %s: %v", clean, err)
		return
	}

	m.cfg = newCfg
	m.configPath = clean
	m.eng = engine.NewEngine(m.cfg, m.log)
	m.refreshMappingsTable()
	m.initForms()
	m.setToast(fmt.Sprintf("Loaded %s (%d mappings)", filepath.Base(clean), len(m.cfg.Mappings)), false)
	m.log.Log(logger.LevelSuccess, "Loaded configuration from: %s", clean)
}

func (m *AppModel) addCurrentMapping() {
	rawTypes := strings.Split(m.mappingData.FileTypes, ",")
	var types []string
	for _, t := range rawTypes {
		tr := strings.TrimSpace(t)
		if tr != "" {
			types = append(types, tr)
		}
	}
	if len(types) == 0 {
		types = []string{"*.*"}
	}

	m.cfg.Mappings = append(m.cfg.Mappings, config.FolderMapping{
		Name:        strings.TrimSpace(m.mappingData.Name),
		Source:      strings.TrimSpace(m.mappingData.Source),
		Destination: strings.TrimSpace(m.mappingData.Destination),
		FileTypes:   types,
		Enabled:     true,
	})

	m.refreshMappingsTable()
	m.setToast(fmt.Sprintf("Added mapping [%s]", m.mappingData.Name), false)
	m.log.Log(logger.LevelSuccess, "Added mapping [%s]: %s -> %s", m.mappingData.Name, m.mappingData.Source, m.mappingData.Destination)
}

func (m *AppModel) removeSelectedMapping() {
	idx := m.mappingsTable.Cursor()
	if idx >= 0 && idx < len(m.cfg.Mappings) {
		name := m.cfg.Mappings[idx].Name
		m.cfg.Mappings = append(m.cfg.Mappings[:idx], m.cfg.Mappings[idx+1:]...)
		m.refreshMappingsTable()
		m.setToast(fmt.Sprintf("Removed mapping [%s]", name), false)
		m.log.Log(logger.LevelWarn, "Removed mapping [%s]", name)
	}
}

func (m *AppModel) toggleSelectedMapping() {
	idx := m.mappingsTable.Cursor()
	if idx >= 0 && idx < len(m.cfg.Mappings) {
		m.cfg.Mappings[idx].Enabled = !m.cfg.Mappings[idx].Enabled
		m.refreshMappingsTable()
		m.setToast(fmt.Sprintf("Mapping [%s] enabled: %v", m.cfg.Mappings[idx].Name, m.cfg.Mappings[idx].Enabled), false)
	}
}

func (m *AppModel) generateAndSaveSSHKey() {
	key, err := GenerateEd25519KeyPair(m.sshWizardData.Comment)
	if err != nil {
		m.setToast(fmt.Sprintf("Key generation failed: %v", err), true)
		return
	}

	targetPath := strings.TrimSpace(m.sshWizardData.SavePath)
	if err := SaveSSHKeyPair(targetPath, key); err != nil {
		m.setToast(fmt.Sprintf("Save key failed: %v", err), true)
		return
	}

	m.generatedSSHKey = key
	m.cfg.Endpoint.PrivateKeyPath = targetPath
	m.setToast(fmt.Sprintf("Ed25519 SSH keypair saved to %s", targetPath), false)
	m.log.Log(logger.LevelSuccess, "Generated & saved Ed25519 SSH key to %s", targetPath)
}

func (m *AppModel) triggerBackgroundSync() tea.Cmd {
	return func() tea.Msg {
		start := time.Now()
		c, f, s := m.eng.RunCycle()
		return SyncResultMsg{
			Copied:  c,
			Failed:  f,
			Skipped: s,
			Elapsed: time.Since(start),
		}
	}
}

func (m *AppModel) triggerTestConnection() tea.Cmd {
	return func() tea.Msg {
		switch m.cfg.Protocol {
		case config.ProtocolSFTP:
			sftpCfg := protocol.SftpConfig{
				Host:           m.cfg.Endpoint.Host,
				Port:           m.cfg.Endpoint.Port,
				Username:       m.cfg.Endpoint.Username,
				Password:       m.cfg.Endpoint.Password,
				PrivateKeyPath: m.cfg.Endpoint.PrivateKeyPath,
				KeyPassphrase:  m.cfg.Endpoint.KeyPassphrase,
				Timeout:        8 * time.Second,
			}
			sftpFS, err := protocol.NewSftpVFS(sftpCfg)
			if err != nil {
				return TestConnResultMsg{Success: false, Message: fmt.Sprintf("SFTP Failed: %v", err)}
			}
			_ = sftpFS.Close()
			return TestConnResultMsg{Success: true, Message: fmt.Sprintf("SFTP to %s:%d Succeeded!", m.cfg.Endpoint.Host, m.cfg.Endpoint.Port)}

		case config.ProtocolLocal, config.ProtocolSMB:
			localFS := protocol.NewLocalVFS()
			var checks []string
			for _, mapItem := range m.cfg.Mappings {
				if _, err := localFS.Stat(mapItem.Source); err != nil {
					checks = append(checks, fmt.Sprintf("%s (src err)", mapItem.Name))
				}
				if _, err := localFS.Stat(mapItem.Destination); err != nil {
					checks = append(checks, fmt.Sprintf("%s (dst err)", mapItem.Name))
				}
			}
			if len(checks) > 0 {
				return TestConnResultMsg{Success: false, Message: fmt.Sprintf("Path warnings: %s", strings.Join(checks, ", "))}
			}
			return TestConnResultMsg{Success: true, Message: "All configured local/UNC paths verified!"}

		default:
			return TestConnResultMsg{Success: true, Message: fmt.Sprintf("Protocol %s configured on port %d", m.cfg.Protocol, m.cfg.Endpoint.Port)}
		}
	}
}

func (m AppModel) View() string {
	var body string

	if m.showOpenFileModal {
		body = m.renderOpenFileModal()
	} else {
		switch m.activeTab {
		case TabDashboard:
			body = m.renderDashboard()
		case TabEndpoint:
			body = m.renderEndpointView()
		case TabMappings:
			body = m.renderMappingsView()
		case TabPolicies:
			body = m.renderPoliciesView()
		case TabSSHWizard:
			body = m.renderSSHWizardView()
		case TabGuide:
			body = m.renderGuideView()
		}
	}

	return StyleApp.Render(lipgloss.JoinVertical(
		lipgloss.Left,
		m.renderHeader(),
		m.renderTabs(),
		body,
		m.renderFooter(),
	))
}

func (m AppModel) renderHeader() string {
	title := StyleHeader.Render(" COPY MASTER ")
	subTitle := StyleSubHeader.Render("Industrial Multi-Protocol Replication Suite (Air-Gapped Standalone)")

	var dirPill string
	switch m.cfg.SyncDirection {
	case config.DirectionPush:
		dirPill = StylePillSuccess.Render("Mode: Push (Upload)")
	case config.DirectionPull:
		dirPill = StylePillPrimary.Render("Mode: Pull (Download)")
	default:
		dirPill = StylePillMuted.Render("Mode: Local")
	}

	protoPill := StylePillPrimary.Render(fmt.Sprintf("%s :%d", m.cfg.Protocol, m.cfg.Endpoint.Port))
	hostStr := m.cfg.Endpoint.Host
	if hostStr == "" {
		hostStr = "Local Node"
	}
	hostPill := StylePillWarning.Render(hostStr)
	cfgPill := StylePillMuted.Render(filepath.Base(m.configPath))

	statusRow := lipgloss.JoinHorizontal(lipgloss.Center, dirPill, " ", protoPill, " ", hostPill, " ", cfgPill)

	topBar := lipgloss.JoinHorizontal(lipgloss.Center, title, subTitle)
	return lipgloss.JoinVertical(lipgloss.Left, topBar, statusRow)
}

func (m AppModel) renderTabs() string {
	tabs := []string{
		"1: Dashboard",
		"2: Endpoint & Auth",
		"3: Mappings",
		"4: Lifecycle & Daemon",
		"5: SSH Wizard",
		"6: Server Guide",
	}

	var renderedTabs []string
	for i, t := range tabs {
		if Tab(i) == m.activeTab {
			renderedTabs = append(renderedTabs, StyleTabActive.Render(t))
		} else {
			renderedTabs = append(renderedTabs, StyleTabInactive.Render(t))
		}
	}

	return lipgloss.NewStyle().Margin(1, 0).Render(lipgloss.JoinHorizontal(lipgloss.Top, renderedTabs...))
}

func (m AppModel) renderFooter() string {
	toast := m.statusToast
	toastStyle := StyleToastSuccess
	if m.toastIsError {
		toastStyle = StyleToastError
	}
	toastRendered := toastStyle.Render(toast)

	syncInd := ""
	if m.isSyncing {
		syncInd = " " + m.spinner.View() + " Syncing... "
	}
	if m.isTesting {
		syncInd = " " + m.spinner.View() + " Testing Connection... "
	}

	keys := lipgloss.JoinHorizontal(
		lipgloss.Center,
		StyleKey.Render("Tab"), StyleKeyDesc.Render(" Next Tab"),
		StyleKey.Render("F2"), StyleKeyDesc.Render(" Sync Now"),
		StyleKey.Render("F3"), StyleKeyDesc.Render(" Save"),
		StyleKey.Render("F4"), StyleKeyDesc.Render(" Test"),
		StyleKey.Render("F5"), StyleKeyDesc.Render(" Open"),
		StyleKey.Render("F10"), StyleKeyDesc.Render(" Quit"),
	)

	statusBar := lipgloss.JoinHorizontal(lipgloss.Center, toastRendered, syncInd)
	return lipgloss.JoinVertical(lipgloss.Left, statusBar, keys)
}

func (m AppModel) renderDashboard() string {
	tableBox := StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(" Configured Folder Mappings "),
			m.mappingsTable.View(),
		),
	)

	consoleBox := StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(" Live Streaming Auditing & System Logs (F2: Trigger Sync) "),
			m.logViewport.View(),
		),
	)

	return lipgloss.JoinVertical(lipgloss.Left, tableBox, consoleBox)
}

func (m AppModel) renderEndpointView() string {
	card := StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(" Section 1: Protocol & Endpoint Authentication "),
			m.endpointForm.View(),
		),
	)
	return card
}

func (m AppModel) renderMappingsView() string {
	if m.showAddMapping {
		return StyleCard.Width(m.tableWidth).Render(
			lipgloss.JoinVertical(
				lipgloss.Left,
				StyleCardTitle.Render(" Add New Folder Mapping "),
				m.addMappingForm.View(),
			),
		)
	}

	instruction := StyleKeyDesc.Render("Hotkeys: [a / +] Add Mapping | [d / -] Remove Selected | [Space] Toggle Status | [Esc] Dashboard")

	return StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(fmt.Sprintf(" Folder Mappings (%d pairs) ", len(m.cfg.Mappings))),
			m.mappingsTable.View(),
			instruction,
		),
	)
}

func (m AppModel) renderPoliciesView() string {
	return StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(" Section 3 & 4: Data Lifecycle, Purging & Scheduler Policies "),
			m.policyForm.View(),
		),
	)
}

func (m AppModel) renderSSHWizardView() string {
	var pubKeyView string
	if m.generatedSSHKey != nil {
		pubKeyView = lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(" Generated Public Key (Add to server authorized_keys): "),
			lipgloss.NewStyle().Foreground(ColorSuccess).Background(lipgloss.Color("#1f2335")).Padding(1).Render(m.generatedSSHKey.PublicKey),
		)
	}

	return StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(" Air-Gapped SSH Key Wizard (Ed25519) "),
			m.sshWizardForm.View(),
			pubKeyView,
		),
	)
}

func (m AppModel) renderGuideView() string {
	return StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(fmt.Sprintf(" Remote Server Setup & Security Guide: %s (Port %d) ", m.cfg.Protocol, m.cfg.Endpoint.Port)),
			m.guideViewport.View(),
		),
	)
}

func (m AppModel) renderOpenFileModal() string {
	return StyleCard.Width(m.tableWidth).Render(
		lipgloss.JoinVertical(
			lipgloss.Left,
			StyleCardTitle.Render(" Open / Load Configuration or Script "),
			m.openFileForm.View(),
			StyleKeyDesc.Render("Tip: Enter path to config.yaml or existing CopyMaster-Script.ps1 | [Esc] Cancel"),
		),
	)
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
