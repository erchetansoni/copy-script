<#
================================================================================
COPY MASTER - TASK SCHEDULER INSTALLER
================================================================================

DESCRIPTION
-----------
Creates (or recreates) a Windows Scheduled Task which executes the
Robocopy synchronization script at a defined interval.

FEATURES
--------
âœ… Creates scheduled task
âœ… Removes existing task if present
âœ… Runs whether user is logged on or not
âœ… Runs with highest privileges
âœ… Auto-start after reboot
âœ… Repeat every X minutes
âœ… Prevents overlapping executions
âœ… Fully configurable

================================================================================
CONFIGURATION
================================================================================
#>
# ==================================================
# CONFIGURATION
# ==================================================

$TaskName = "Copy Master"

# Automatically detects CopyScript.ps1 in the current script folder
$ScriptPath = "$PSScriptRoot\CopyScript.ps1"

# Auto-resolve to absolute path if run interactively in console
if (-not $PSScriptRoot -or -not [System.IO.Path]::IsPathRooted($ScriptPath))
{
    $baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $ScriptPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, "CopyScript.ps1"))
}

$RunAsUser = "SYSTEM"

$RepeatMinutes = 1

# ==================================================
# DELETE IF EXISTS
# ==================================================

schtasks /Delete /TN "$TaskName" /F 2>$null

# ==================================================
# CREATE TASK
# ==================================================

schtasks /Create `
    /TN "$TaskName" `
    /SC MINUTE `
    /MO $RepeatMinutes `
    /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`"" `
    /RU $RunAsUser `
    /RL HIGHEST `
    /F

# ==================================================
# DISPLAY RESULT
# ==================================================

schtasks /Query /TN "$TaskName" /V /FO LIST
