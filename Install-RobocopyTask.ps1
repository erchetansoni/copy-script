<#
================================================================================
EVS TASK SCHEDULER INSTALLER
================================================================================

DESCRIPTION
-----------
Creates (or recreates) a Windows Scheduled Task which executes the
Robocopy synchronization script at a defined interval.

FEATURES
--------
✅ Creates scheduled task
✅ Removes existing task if present
✅ Runs whether user is logged on or not
✅ Runs with highest privileges
✅ Auto-start after reboot
✅ Repeat every X minutes
✅ Prevents overlapping executions
✅ Fully configurable

================================================================================
CONFIGURATION
================================================================================
#>
# ==================================================
# CONFIGURATION
# ==================================================

$TaskName = "Copy Script v3"

$ScriptPath = "C:\temp\TEST\copy-script-v3.ps1"

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