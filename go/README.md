# Copy Master - Modern Go Standalone Edition

> **Industrial Multi-Protocol Replication Agent & Air-Gapped Terminal Suite**  
> Built with the **Charm Toolchain**: Bubble Tea, Bubbles, Lip Gloss, and Huh.

---

## 🎨 Charm Architecture Stack
- **Bubble Tea (`github.com/charmbracelet/bubbletea`)**: Application lifecycle & Elm architecture (`Init`, `Update`, `View`).
- **Bubbles (`github.com/charmbracelet/bubbles`)**: Table, Viewport, Spinner, and interactive components.
- **Lip Gloss (`github.com/charmbracelet/lipgloss`)**: Industrial dark theme, rounded borders, pills, badges, and layout.
- **Huh (`github.com/charmbracelet/huh`)**: Form validation, select dropdowns, password masking, and interactive forms.

---

## 📁 Directory Layout
```
go/
├── cmd/
│   └── copymaster/
│       ├── main.go                     # Entry point, flag parser & signal handler
│       ├── console_windows.go          # Double-click detection for Windows
│       ├── console_other.go            # Non-Windows console fallback
│       ├── versioninfo.json            # Windows PE metadata definition
│       └── resource_windows_amd64.syso # Embedded Windows resource & manifest
├── internal/
│   ├── config/                         # YAML/JSON config parser and validator
│   ├── engine/                         # Replication engine & lifecycle policies
│   ├── logger/                         # Thread-safe dual logger with dynamic event hooks
│   ├── protocol/                       # SFTP (crypto/ssh) and Local VFS abstractions
│   └── tui/                            # Charm TUI implementation
│       ├── app.go                      # Bubble Tea model (Dashboard, Tabs, Keybindings)
│       ├── forms.go                    # Huh interactive forms
│       ├── styles.go                   # Lip Gloss theme & styling
│       ├── guide.go                    # Server setup & firewall guide generator
│       ├── sshkeygen.go                # Native Ed25519 SSH keypair generator
│       └── script_parser.go            # Importer for legacy PowerShell scripts & YAML
├── build/
│   ├── Build-Binaries.ps1              # Windows cross-compilation pipeline
│   └── build.sh                        # Linux/macOS cross-compilation script
└── bin/
    ├── copymaster.exe                  # Windows 64-bit standalone executable (~7.2 MB)
    ├── copymaster-linux-amd64          # Linux x86_64 statically linked binary (~7.0 MB)
    └── copymaster-linux-arm64          # Linux ARM64 statically linked binary (~6.6 MB)
```

---

## 🚀 Quick Start

### 1. Launch Interactive Terminal UI
```bash
# Windows
.\bin\copymaster.exe

# Linux
./bin/copymaster-linux-amd64
```

### 2. Hotkey Controls
| Key | Action |
| :--- | :--- |
| **`Tab` / `Shift+Tab`** | Cycle through navigation tabs (Dashboard, Endpoint, Mappings, Policies, SSH Wizard, Server Guide) |
| **`1` - `6`** | Jump directly to tab: 1 (Dashboard), 2 (Endpoint), 3 (Mappings), 4 (Policies), 5 (SSH Wizard), 6 (Guide) |
| **`F2`** | **Run Sync Now** (Immediate replication with animated spinner & real-time log streaming) |
| **`F3`** | **Save Configuration** (Validates and writes to `config.yaml`) |
| **`F4`** | **Test Connection** (Tests remote endpoint reachability & credentials) |
| **`F5`** | **Open / Import** (Load from YAML or import legacy PowerShell script) |
| **`F6`** | **Remote Server Setup Guide** |
| **`F7`** | **SSH Key Wizard** (Generate & save Ed25519 keypair) |
| **`F10`** | **Quit** |

### 3. Headless Automation (Task Scheduler / Cron)
```bash
# Execute single replication cycle and exit
copymaster.exe -config config.yaml -once

# Continuous daemon mode
copymaster.exe -config config.yaml -daemon
```

