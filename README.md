# Avgol Copy Master

> **Industrial Multi-Folder Robocopy Replication & Data Lifecycle Suite**  
> Designed for mission-critical industrial automation, vision inspection systems (EVS), and air-gapped production environments.

---

## 📋 Table of Contents
1. [Overview & Highlights](#-overview--highlights)
2. [Architecture & Workflow](#-architecture--workflow)
3. [Quick Start Guide](#-quick-start-guide)
4. [Feature Reference](#-feature-reference)
   - [SMB Authentication & Connectivity](#1-smb-authentication--connectivity)
   - [Multi-Folder Mapping Engine](#2-multi-folder-mapping-engine)
   - [Data Lifecycle & Retention Policies](#3-data-lifecycle--retention-policies)
   - [Windows Scheduled Task Deployment](#4-windows-scheduled-task-deployment)
5. [Viewing & Managing in Windows Task Scheduler](#-viewing--managing-in-windows-task-scheduler)
6. [Logs, Auditing & Rotation](#-logs-auditing--rotation)
7. [Comprehensive Troubleshooting & Diagnostics Guide](#-comprehensive-troubleshooting--diagnostics-guide)
8. [Automated End-to-End Testing (E2E)](#-automated-end-to-end-testing-e2e)
9. [Air-Gapped Deployment Checklist](#-air-gapped-deployment-checklist)

---

## 🌟 Overview & Highlights

**Avgol Copy Master** provides automated, resilient, and verified file synchronization between remote machine controllers (SMB/CIFS shares) and local storage servers.

- **100% Air-Gap Compatible**: Zero external runtime dependencies. Runs natively on Windows 10/11 and Windows Server 2016/2019/2022 using pure PowerShell 5.1 and Win32 utilities (`robocopy.exe`, `schtasks.exe`, `net.exe`).
- **Modern WPF Desktop GUI**: 1-click launcher (`Launch-AvgolCopyMaster.bat`) with automatic Administrator UAC elevation, high-contrast dark theme, and real-time console auditing.
- **Resilient Robocopy Core**: Uses industrial Robocopy flags (`/E`, `/Z` restartable mode, `/FFT` 2-second timestamp tolerance, `/XO` exclude older unchanged files, `/R:5 /W:15` automatic retry with wait, `/NP /TEE /LOG+`).
- **Complete Data Lifecycle Management**:
  - **Verified Source Cleanup**: Safely deletes source files older than $X$ days **only after** verifying that the file exists at the local destination with an identical byte count.
  - **Monthly Auto-Archive**: Automatically moves prior months' data into `YYYY-MM` subfolders (e.g., `2026-09\`), keeping the destination root dedicated to current-month production.
  - **Archive Purge Policy**: Automatically prunes historical `YYYY-MM` destination folders older than $X$ months.
- **Automated Windows Scheduled Task**: Configures continuous background replication running under the `SYSTEM` or administrative account with highest privileges.

---

## 🏗 Architecture & Workflow

```
[ Remote Machine Controller / SMB Share ]
    e.g. \\10.91.13.204\qw\Test1\*.csv
                     │
                     │  (1) Authenticate session (net use)
                     │  (2) Robocopy sync (/E /Z /FFT /XO /XD 20* /XF <archived>)
                     ▼
[ Local Destination Storage ]
    e.g. C:\temp\TEST\data1\
         ├── file_today.csv          <-- Current Month Data (Kept at root)
         │
         ├── [ 2026-09 ]             <-- Auto-Archived Previous Months
         │   └── file_sept.csv
         │
         └── [ 2026-08 ]             <-- Auto-Archived Previous Months
             └── file_aug.csv
                     │
                     │  (3) Monthly Auto-Archive: Moves files < CurrentMonth into YYYY-MM
                     │  (4) Archive Purge: Deletes YYYY-MM folders older than X months
                     │  (5) Source Cleanup: Deletes verified remote files older than X days
                     ▼
[ Audited Logs ]
    C:\temp\TEST\Logs\
    ├── Robocopy_Current.log         <-- High-level operational summary
    ├── Robocopy_Detail.log          <-- Detailed Robocopy file-by-file log
    └── Robocopy_YYYYMMDD_HHMMSS.log <-- Auto-rotated archives (Max 20, 10MB each)
```

---

## 🚀 Quick Start Guide

### Step 1: Launch the Configurator
Right-click or double-click `Launch-AvgolCopyMaster.bat`.
- The launcher automatically detects if administrative privileges are present. If not, Windows prompts for UAC elevation.
- The **Avgol Copy Master** GUI window opens.

### Step 2: Configure Remote SMB Credentials
1. In **Section 1 (Remote Source Authentication)**, enter the domain or IP username (e.g., `10.91.13.204\admin`).
2. Enter the password (click the **Show** checkbox to verify typing).
3. Click **Test SMB Connection** to test connectivity to the remote server.

### Step 3: Add Folder Mappings
1. In **Section 2 (Folder Mappings)**, fill in:
   - **Name**: A descriptive label (e.g., `Line 1 - Vision Inspection`).
   - **Source UNC Path**: Full network share path (e.g., `\\10.91.13.204\qw\Test1`).
   - **Destination Local Path**: Local target folder (e.g., `C:\Data\Line1`). Click `...` to browse.
   - **File Types**: File filter (e.g., `*.csv` or `*.csv, *.log`).
2. Click **+ Add Mapping**. Repeat for all production lines or cameras.

### Step 4: Configure Data Lifecycle Policies (Optional)
In **Section 3 (Data Lifecycle & Archive Policies)**:
- **Source Deletion**: Check `Delete data at Source(s) after replication`. A warning dialog will confirm your intent. Specify the age threshold (e.g., `30` days).
- **Monthly Auto-Archive**: Check `Auto-Archive at Destination (Monthly YYYY-MM structure)` to group older files into folders like `2026-09`.
- **Destination Archive Purge**: Check `Delete old monthly archive folders at Destination`. A warning dialog will confirm your intent. Specify the retention in months (e.g., `6` or `12` months).

### Step 5: Deploy & Install Scheduled Task
1. In **Section 4 (Deployment & Task Scheduler)**:
   - **Target Script Folder**: Where the production script will be saved (e.g., `C:\Scripts`).
   - **Script File Name**: `copy-script.ps1`.
   - **Scheduled Task Name**: `Avgol Copy Master` (or `Copy Script v3`).
   - **Interval**: Execution frequency in minutes (e.g., `1` or `5` minutes).
2. Click **Deploy Script & Install Scheduled Task**.
   - The UI validates the PowerShell script using the language parser (0 syntax errors guaranteed).
   - Saves the script to disk.
   - Automatically registers the Windows Scheduled Task with highest privileges.
3. Click **Run Replication Now** to test execution immediately and view results in the console.

---

## ⚙️ Feature Reference

### 1. SMB Authentication & Connectivity
- Remote Windows and Linux SMB/CIFS shares often require explicit network sessions when running unattended.
- Avgol Copy Master automatically detects all unique root shares from your configured UNC paths (e.g., `\\10.91.13.204\qw`).
- It establishes non-persistent SMB credential sessions (`net use "\\server\share" /user:Domain\User Password /persistent:no`) before Robocopy starts, avoiding Windows drive-letter dependencies.

### 2. Multi-Folder Mapping Engine
- Supports an arbitrary number of folder mappings across different servers, shares, and local drives.
- Each mapping is isolated: a failure on one mapping (e.g., camera offline) does not halt synchronization of other lines.
- Robocopy automatically creates missing destination directories on demand.

### 3. Data Lifecycle & Retention Policies
| Policy | Setting | Behavior | Safety Guarantee |
| :--- | :--- | :--- | :--- |
| **Source File Cleanup** | `$EnableSourceDelete = $true`<br>`$SourceDeleteDays = 30` | Scans remote source files older than $X$ days from their `LastWriteTime`. | **Verified Copy Check**: The source file is deleted **only** if an identical file (same name & exact byte length) exists at the local destination (root or monthly archive). |
| **Monthly Auto-Archive** | `$EnableDestMonthlyArchive = $true` | Scans destination root files. Files modified prior to `00:00:00` on the 1st of the current month are moved into `YYYY-MM\` folders. | Robocopy exclusions `/XD 20*` and dynamic `/XF` prevent Robocopy from re-copying files that are already archived. |
| **Archive Purge** | `$EnableDestArchiveDelete = $true`<br>`$DestArchiveDeleteMonths = 6` | Scans destination directories matching `YYYY-MM`. | Purges folders where `folderDate < currentMonthStart.AddMonths(-X)`. Current and recent months are strictly preserved. |

### 4. Windows Scheduled Task Deployment
- Installs via `schtasks.exe` with `/RL HIGHEST` and `/RU SYSTEM` (or administrative user).
- Runs continuously at the configured interval without requiring a user to remain logged on.
- Uses `-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\copy-script.ps1"`.

---

## 🖥 Viewing & Managing in Windows Task Scheduler

### How to Inspect the Task in Windows GUI (`taskschd.msc`)
1. Press `Win + R`, type **`taskschd.msc`**, and press Enter.
2. In the left navigation tree, select **Task Scheduler Library**.
3. In the center pane, find your task name (e.g., **`Copy Script v3`** or **`Avgol Copy Master`**).
4. Review key properties:
   - **Status**: Should display `Ready` or `Running`.
   - **Triggers**: Displays the repetition interval (e.g., `At 12:00 AM every day - After triggered, repeat every 1 minute indefinitely`).
   - **Actions**: Displays `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\copy-script.ps1"`.
   - **Run with highest privileges**: Checked.
   - **Last Run Time** and **Last Run Result**: `0x0` indicates successful execution.

### Managing via PowerShell / Command Prompt
```powershell
# Query task status and detailed schedule
schtasks /Query /TN "Copy Script v3" /V /FO LIST

# Trigger manual task run immediately
schtasks /Run /TN "Copy Script v3"

# Stop a running task
schtasks /End /TN "Copy Script v3"

# Disable the task temporarily
schtasks /Change /TN "Copy Script v3" /DISABLE

# Re-enable the task
schtasks /Change /TN "Copy Script v3" /ENABLE

# Delete the task completely
schtasks /Delete /TN "Copy Script v3" /F
```

---

## 📊 Logs, Auditing & Rotation

### Log Locations
All logs are written to the configured **Log Directory** (default: `C:\temp\TEST\Logs` or `C:\Scripts\Logs`):

| Log File | Purpose | Contents |
| :--- | :--- | :--- |
| **`Robocopy_Current.log`** | Primary operational summary | Timestamps, SMB connection results, mapping start/end, file counts, lifecycle actions (archives, source deletions, purges), and cycle status. |
| **`Robocopy_Detail.log`** | Full Robocopy technical log | Verbose file-by-file output, byte transfers, transfer speeds, directory matching, and Robocopy exit codes. |
| **`Robocopy_YYYYMMDD_HHMMSS.log`** | Historical rotated archives | Automatically generated when `Robocopy_Current.log` or `Robocopy_Detail.log` exceeds configured size limit (e.g., 10 MB). |

### Automatic Log Rotation & Retention
- **Size-Based Rotation**: When a log exceeds `MaxLogSizeMB` (default: `10 MB`), it is archived as `Robocopy_YYYYMMDD_HHMMSS.log`, and a fresh active log is initialized.
- **Archive Count Limit**: Retains up to `MaxArchivedLogs` (default: `20`) newest archives; older archives are automatically pruned.
- **Time-Based Retention**: `Cleanup-OldLogs` automatically removes any log older than `LogRetentionDays` (default: `30` days).

---

## 🔧 Comprehensive Troubleshooting & Diagnostics Guide

### 1. Robocopy Exit Codes Reference
Robocopy uses bitmap exit codes where values $\le 7$ are non-fatal successes:

| Exit Code | Meaning | Severity | Action Required |
| :---: | :--- | :--- | :--- |
| **0** | No files were copied (destination already in sync). | Normal | None. All files up to date. |
| **1** | One or more files were copied successfully. | Normal | None. Copy succeeded. |
| **2** | Extra files/directories exist in destination that do not exist in source. | Normal | Expected when destination retains older or archived files. |
| **3** | Files copied ($1$) + extra files detected ($2$). | Normal | None. Healthy synchronization. |
| **4** | Mismatched files detected. | Warning | Inspect `Robocopy_Detail.log` for file attributes or lock issues. |
| **5** | Files copied ($1$) + mismatches ($4$). | Warning | Check for in-use source files. |
| **6** | Extras ($2$) + mismatches ($4$). | Warning | Check for in-use files. |
| **7** | Files copied ($1$) + extras ($2$) + mismatches ($4$). | Warning | Check for in-use files. |
| **$\ge 8$** | Fatal error. Robocopy could not copy one or more files. | **Error** | Network dropped, access denied, or disk full. See below. |

---

### 2. Common Errors and Solutions

#### Issue: "Access is denied" (System Error 5)
- **Cause**: The SMB credentials in Section 1 do not have read/write access to the remote share, or local destination permissions are restricted.
- **Resolution**:
  1. Open the UI, re-enter username as `DOMAIN\User` or `IP\User` (e.g. `10.91.13.204\admin`), re-enter password, and click **Test SMB Connection**.
  2. If using Task Scheduler under `SYSTEM`, ensure the remote share grants access to the specified credentials, as `SYSTEM` does not pass local domain credentials across SMB without `net use`.

#### Issue: "The network path was not found" (System Error 53)
- **Cause**: Remote machine is powered off, firewalled, or IP is unreachable.
- **Resolution**:
  1. Test ping: `Test-NetConnection -ComputerName 10.91.13.204 -Port 445`.
  2. Ensure Windows Firewall on the remote machine allows **File and Printer Sharing (SMB-In)** on port 445.

#### Issue: "Files are not being deleted from source"
- **Cause**:
  1. The file modified date is less than the configured retention days ($< 30$ days).
  2. **Safety guard triggered**: The file has not yet been copied to the local destination, or the destination file byte length does not match the source.
  3. The remote SMB user does not have `Modify` / `Delete` permissions on the source folder.
- **Resolution**: Check `Robocopy_Current.log`. Look for lines tagged `[SOURCE CLEANUP]`. It explicitly states whether a file was deleted, skipped due to age, or pending destination verification.

#### Issue: "Scheduled task shows Last Run Result 0x1"
- **Cause**: PowerShell script execution policy blocked execution or script path was incorrect.
- **Resolution**:
  1. In Task Scheduler, verify the task arguments:
     `-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\copy-script.ps1"`
  2. Test manually in an elevated command prompt:
     `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\copy-script.ps1"`

---

---

## 🧪 Automated End-to-End Testing (E2E)

Avgol Copy Master includes a native, 21-point automated test suite [`Test-AvgolCopyMaster-E2E.ps1`](file:///c:/Projects/Companies/Avgol/Copy-Script/Test-AvgolCopyMaster-E2E.ps1) for validating complete system health without requiring manual configuration.

### How to Run

#### Option A: Offline Local Sandbox Mode (Recommended for Air-Gapped Machines)
Requires no network shares, domain controllers, or internet connection:
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Test-AvgolCopyMaster-E2E.ps1
```

#### Option B: Live SMB Remote Share Testing
Validates against an active network UNC share with credentials:
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Test-AvgolCopyMaster-E2E.ps1 `
    -RemoteUNC "\\10.91.13.204\qw\E2E_Test" `
    -Username "10.91.13.204\admin" `
    -Password "Avgol2002"
```

### What is Verified Automatically:
1. **AST Parser Syntax Check**: Verifies that both the UI generator and core replication script have 0 syntax errors.
2. **Automated Fixture Generation**: Creates test files with timestamps simulating today, last month, and >30 days ago, plus expired and retained archive folders.
3. **Template Extraction & Code Generation**: Dynamically compiles the replication script and verifies AST integrity.
4. **Pass 1 Execution**: Tests Robocopy synchronization, destination monthly archiving (`YYYY-MM`), archive purging, and verified source file cleanup.
5. **Post-Replication Assertions**: Confirms that:
   - Current month data stays at destination root.
   - Previous month data moves to `YYYY-MM`.
   - Expired archive folders are permanently pruned.
   - Source files are safely deleted only after byte-matching destination verification.
6. **Pass 2 Loop Prevention Check**: Re-runs replication to verify that Robocopy `/XD 20*` and `/XF` exclusions prevent archived files from being re-copied back to root.
7. **Log Rotation Audit**: Verifies that `Robocopy_Current.log` records both operational events and Robocopy synchronization summaries.

---

## 🔒 Air-Gapped Deployment Checklist

When deploying to an isolated industrial plant without internet access:

1. **Copy Repository**: Copy the entire repository folder to the plant workstation or server (e.g., `C:\Avgol-CopyMaster\`).
2. **Verify Dependencies**: Confirm standard Windows utilities exist:
   - `powershell.exe` (Windows PowerShell 5.1 built into Windows 10/11/Server).
   - `robocopy.exe` (built into `C:\Windows\System32\`).
   - `schtasks.exe` (built into `C:\Windows\System32\`).
3. **Run Self-Test**: Run `powershell.exe -ExecutionPolicy Bypass -File .\Test-AvgolCopyMaster-E2E.ps1` to confirm system functionality (21/21 passes).
4. **Launch**: Double-click `Launch-AvgolCopyMaster.bat`.
5. **Configure & Deploy**: Set Source UNC paths, local destinations, credentials, and click **Deploy Script & Install Scheduled Task**.
6. **Verify**: Open `C:\Scripts\Logs\Robocopy_Current.log` to confirm continuous replication cycles.
