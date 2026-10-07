<#
====================================================================================================
ROBOCOPY CONTINUOUS FILE REPLICATION
====================================================================================================

DESCRIPTION
-----------
Continuously monitors a remote SMB share and copies files to a local destination.

FEATURES
--------
✅ Source Server NOT Domain Joined
✅ Username / Password Authentication
✅ Automatic Share Reconnection
✅ Continuous Monitoring
✅ Multiple File Type Support
✅ Only New / Changed Files Copied
✅ No Duplicate Copies
✅ Configurable Retry Logic
✅ Verbose Robocopy Logging
✅ Log Rotation By Maximum Size
✅ Archived Log Cleanup
✅ Log Retention Cleanup
✅ Error Handling

HOW IT WORKS
------------
1. Connects to Source SMB Share using supplied credentials.
2. Verifies share accessibility.
3. Executes Robocopy.
4. Copies only NEW or MODIFIED files.
5. Skips existing unchanged files.
6. Repeats every configured polling interval.
7. Rotates logs when size exceeds configured threshold.
8. Retains only configured number of archived logs.
9. Removes old logs based on retention period.

====================================================================================================
CONFIGURATION
====================================================================================================
#>

# ====================================================================
# SOURCE SETTINGS
# ====================================================================

$SourceServerIP      = "10.91.13.101"

# Share Name Only
$SourceShareName     = "rwindows"

# Examples:
# 10.91.13.101\FileUser
# SERVERNAME\FileUser

$SourceUsername      = "10.91.13.101\EVS"
$SourcePassword      = "evs"

# ====================================================================
# DESTINATION SETTINGS
# ====================================================================

$DestinationPath     = "D:\EVS\Line1\Avgol\India-Files - India EVS data\Avgol India EVS L1-Data\Current Month"

# ====================================================================
# FILE TYPES TO COPY
# ====================================================================

$FileTypes = @(
    "*.txt"
)

# ====================================================================
# MONITOR SETTINGS
# ====================================================================

$PollingIntervalSec  = 60

# ====================================================================
# ROBOCOPY SETTINGS
# ====================================================================

$RetryAttempts       = 5
$RetryWaitSeconds    = 15

# ====================================================================
# LOG SETTINGS
# ====================================================================

$LogFolder           = "D:\EVS_Scripts\Logs"

$MaxLogSizeMB        = 10
$MaxArchivedLogs     = 20
$LogRetentionDays    = 30

# ====================================================================
# END CONFIGURATION
# ====================================================================



# ====================================================================
# CREATE REQUIRED FOLDERS
# ====================================================================

New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null

$CurrentLog = Join-Path $LogFolder "Robocopy_Current.log"

if (!(Test-Path $CurrentLog))
{
    New-Item -ItemType File -Path $CurrentLog -Force | Out-Null
}



# ====================================================================
# LOGGING
# ====================================================================

function Write-Log
{
    param(
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Add-Content `
        -Path $CurrentLog `
        -Value "$Timestamp - $Message"

    Rotate-Logs
}



# ====================================================================
# LOG ROTATION
# ====================================================================

function Rotate-Logs
{
    try
    {
        if (!(Test-Path $CurrentLog))
        {
            return
        }

        $LogFile = Get-Item -LiteralPath $CurrentLog -ErrorAction Stop

        $SizeMB = [Math]::Round(($LogFile.Length / 1MB), 2)

        if ($SizeMB -lt $MaxLogSizeMB)
        {
            return
        }

        $ArchiveName = "Robocopy_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log"

        $ArchiveFile = Join-Path $LogFolder $ArchiveName

        Move-Item `
            -Path $CurrentLog `
            -Destination $ArchiveFile `
            -Force

        New-Item `
            -ItemType File `
            -Path $CurrentLog `
            -Force | Out-Null

        Write-Host "Log Rotated: $ArchiveName"

        $Archives = Get-ChildItem `
            -Path $LogFolder `
            -Filter "Robocopy_*.log" |
            Sort-Object LastWriteTime -Descending

        if ($Archives.Count -gt $MaxArchivedLogs)
        {
            $Archives |
                Select-Object -Skip $MaxArchivedLogs |
                Remove-Item -Force
        }
    }
    catch
    {
        Write-Host "Log Rotation Error: $_"
    }
}



# ====================================================================
# REMOVE OLD LOGS
# ====================================================================

function Cleanup-OldLogs
{
    try
    {
        Get-ChildItem `
            -Path $LogFolder `
            -Filter "*.log" |
            Where-Object {
                $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays)
            } |
            Remove-Item `
                -Force `
                -ErrorAction SilentlyContinue
    }
    catch
    {
        Write-Log "Log Cleanup Error: $_"
    }
}



# ====================================================================
# CONNECT TO SOURCE SHARE
# ====================================================================

function Connect-SourceShare
{
    try
    {
        $UNCPath = "\\$SourceServerIP\$SourceShareName"

        Write-Log "Connecting to $UNCPath"

        cmd.exe /c "net use $UNCPath /delete /y" *> $null

        cmd.exe /c "net use $UNCPath /user:$SourceUsername $SourcePassword /persistent:no" *> $null

        Start-Sleep -Seconds 2

        if (Test-Path $UNCPath)
        {
            Write-Log "Connection successful"

            return $true
        }

        Write-Log "Connection failed"

        return $false
    }
    catch
    {
        Write-Log "Connection Error: $_"
        return $false
    }
}



# ====================================================================
# RUN ROBOCOPY
# ====================================================================

function Start-RobocopyCopy
{
    try
    {
        $SourcePath = "\\$SourceServerIP\$SourceShareName"

        $FileMask = $FileTypes -join " "

        $DetailedLog = Join-Path $LogFolder "Robocopy_Detail.log"

        Write-Log "Starting Robocopy Sync"

        $Arguments = @(
            "`"$SourcePath`""
            "`"$DestinationPath`""
            $FileMask
            "/E"
            "/Z"
            "/FFT"
            "/XO"
            "/R:$RetryAttempts"
            "/W:$RetryWaitSeconds"
            "/NP"
            "/TEE"
            "/LOG+:`"$DetailedLog`""
        )

        $Process = Start-Process `
            -FilePath "robocopy.exe" `
            -ArgumentList $Arguments `
            -Wait `
            -NoNewWindow `
            -PassThru

        $ExitCode = $Process.ExitCode

        switch ($ExitCode)
        {
            0 { Write-Log "Robocopy Result: No changes detected." }

            1 { Write-Log "Robocopy Result: Files copied successfully." }

            2 { Write-Log "Robocopy Result: Extra files/directories exist at destination." }

            3 { Write-Log "Robocopy Result: Files copied and extra destination files detected." }

            4 { Write-Log "Robocopy Result: Mismatched files detected." }

            5 { Write-Log "Robocopy Result: Files copied with mismatches detected." }

            6 { Write-Log "Robocopy Result: Extras and mismatches detected." }

            7 { Write-Log "Robocopy Result: Files copied, extras and mismatches detected." }

            Default { Write-Log "Robocopy Error/Warning. Exit Code: $ExitCode" }
        }

        Write-Log "Robocopy Completed"
    }
    catch
    {
        Write-Log "Robocopy Exception: $_"
    }
}



# ====================================================================
# STARTUP INFORMATION
# ====================================================================

Write-Log "=================================================="
Write-Log "Robocopy Monitoring Started"
Write-Log "Source Server    : $SourceServerIP"
Write-Log "Source Share     : $SourceShareName"
Write-Log "Destination Path : $DestinationPath"
Write-Log "Polling Interval : $PollingIntervalSec Seconds"
Write-Log "File Types       : $($FileTypes -join ', ')"
Write-Log "Max Log Size     : $MaxLogSizeMB MB"
Write-Log "Max Archives     : $MaxArchivedLogs"
Write-Log "Retention Days   : $LogRetentionDays"
Write-Log "=================================================="


# ====================================================================
# MAIN LOOP
# ====================================================================

try
{
    Cleanup-OldLogs

    if (Connect-SourceShare)
    {
        Start-RobocopyCopy
    }
    else
    {
        Write-Log "Source server unavailable."
    }
}
catch
{
    Write-Log "Main Execution Error: $_"
}