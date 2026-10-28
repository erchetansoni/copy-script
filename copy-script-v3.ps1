<#
====================================================================================================
ROBOCOPY CONTINUOUS FILE REPLICATION - MULTI-FOLDER MAPPING
====================================================================================================

DESCRIPTION
-----------
Monitors a remote SMB share and replicates files from multiple source folders to their respective
destinations on the local machine using Robocopy.

FEATURES
--------
✅ Source Server NOT Domain Joined
✅ Username / Password Authentication
✅ Automatic Share Reconnection
✅ Multiple Source-to-Destination Folder Mappings
✅ Multiple File Type Support (Global & Per-Folder)
✅ Only New / Changed Files Copied
✅ No Duplicate Copies
✅ Configurable Retry Logic
✅ Verbose Robocopy Logging
✅ Log Rotation By Maximum Size (Current & Detail Logs)
✅ Archived Log Cleanup
✅ Log Retention Cleanup
✅ Per-Folder Error Handling & Status Reporting

HOW IT WORKS
------------
1. Authenticates and connects to the Source SMB Share using supplied credentials.
2. Iterates through each configured Folder Mapping.
3. Automatically creates local destination folder if it doesn't exist.
4. Executes Robocopy for each mapped folder pair.
5. Copies only NEW or MODIFIED files (/XO /FFT /Z /E).
6. Skips existing unchanged files.
7. Logs detailed Robocopy operations per folder.
8. Rotates logs when size exceeds configured threshold.
9. Removes old logs based on retention period.

====================================================================================================
CONFIGURATION
====================================================================================================
#>

# ====================================================================
# SOURCE SERVER AUTHENTICATION
# ====================================================================
# Credentials used to authenticate to remote SMB shares.
# Examples:
# 10.91.13.101\FileUser
# SERVERNAME\FileUser

$SourceUsername      = "10.91.13.204\admin"
$SourcePassword      = "Avgol2002"

# Note: If you provide Full UNC paths in $FolderMappings below
# (e.g. "\\10.91.13.101\c\PerfLogs"), $SourceShareName is NOT needed.
# (Optional fallback for relative subfolder paths only):
# $SourceServerIP    = "10.91.13.101"
# $SourceShareName   = "rwindows"

# ====================================================================
# FOLDER MAPPINGS (SOURCE FOLDER -> DESTINATION FOLDER)
# ====================================================================
# Easily map multiple source folders to different destination paths.
#
# HOW TO CONFIGURE:
#   - Name        : (Optional) Friendly label for logging (e.g., "Line 1")
#   - Source      : Subfolder inside the share (e.g., "Line1" or "Line1\Data").
#                   Leave as "" or "\" to copy the root of the share.
#                   Or provide a full UNC path (e.g., "\\10.91.13.101\rwindows\Line1").
#   - Destination : Target folder path on local drive or network.
#   - Enabled     : (Optional) Set to $false to temporarily skip a folder.
#   - FileTypes   : (Optional) Override global $FileTypes for this specific folder.
#
# To add a new folder, simply copy and paste a block below:
# ====================================================================

$FolderMappings = @(
    @{
        Name        = "Line 1"
        Source      = "\\10.91.13.204\qw\Test1"
        Destination = "C:\temp\TEST\data1"
        Enabled     = $true
    },
    @{
        Name        = "Line 2"
        Source      = "\\10.91.13.204\qw\test2"
        Destination = "C:\temp\TEST\data2"
        Enabled     = $true
    }
    # Add more folders as needed:
    # ,@{
    #     Name        = "Line 3"
    #     Source      = "Line3"
    #     Destination = "D:\EVS\Line3\Avgol\India-Files - India EVS data\Avgol India EVS L3-Data\Current Month"
    #     Enabled     = $true
    # }
)

# Optional Fallback (Used only if $FolderMappings is empty)
# $DestinationPath     = "D:\EVS\Line1\Avgol\India-Files - India EVS data\Avgol India EVS L1-Data\Current Month"

# ====================================================================
# DEFAULT FILE TYPES TO COPY
# ====================================================================

$FileTypes = @(
    "*.csv"
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

$LogFolder           = "C:\temp\TEST\Logs"

$MaxLogSizeMB        = 10
$MaxArchivedLogs     = 20
$LogRetentionDays    = 30

# ====================================================================
# END CONFIGURATION
# ====================================================================



# ====================================================================
# CREATE REQUIRED LOG DIRECTORY
# ====================================================================

try
{
    New-Item -ItemType Directory -Path $LogFolder -Force -ErrorAction SilentlyContinue | Out-Null
}
catch {}

$CurrentLog = [System.IO.Path]::Combine($LogFolder, "Robocopy_Current.log")

try
{
    if (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue)
    {
        if (!(Test-Path -LiteralPath $CurrentLog))
        {
            New-Item -ItemType File -Path $CurrentLog -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
catch {}



# ====================================================================
# LOGGING
# ====================================================================

function Write-Log
{
    param(
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FormattedMessage = "$Timestamp - $Message"

    Write-Host $FormattedMessage

    try
    {
        if ($CurrentLog -and (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue))
        {
            Add-Content `
                -Path $CurrentLog `
                -Value $FormattedMessage `
                -ErrorAction SilentlyContinue

            Rotate-Logs
        }
    }
    catch {}
}



# ====================================================================
# LOG ROTATION
# ====================================================================

function Rotate-SingleLog
{
    param(
        [string]$LogFilePath,
        [string]$ArchivePrefix
    )

    try
    {
        if ([string]::IsNullOrWhiteSpace($LogFilePath) -or !(Test-Path -LiteralPath $LogFilePath -ErrorAction SilentlyContinue))
        {
            return
        }

        $LogFile = Get-Item -LiteralPath $LogFilePath -ErrorAction Stop

        $SizeMB = [Math]::Round(($LogFile.Length / 1MB), 2)

        if ($SizeMB -lt $MaxLogSizeMB)
        {
            return
        }

        $ArchiveName = "$($ArchivePrefix)" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log"
        $ArchiveFile = [System.IO.Path]::Combine($LogFolder, $ArchiveName)

        Move-Item `
            -Path $LogFilePath `
            -Destination $ArchiveFile `
            -Force

        New-Item `
            -ItemType File `
            -Path $LogFilePath `
            -Force | Out-Null

        Write-Host "Log Rotated: $ArchiveName"

        $Archives = Get-ChildItem `
            -Path $LogFolder `
            -Filter "$($ArchivePrefix)*.log" `
            -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        if ($Archives.Count -gt $MaxArchivedLogs)
        {
            $Archives |
                Select-Object -Skip $MaxArchivedLogs |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Write-Host "Log Rotation Error ($LogFilePath): $_"
    }
}

function Rotate-Logs
{
    Rotate-SingleLog -LogFilePath $CurrentLog -ArchivePrefix "Robocopy_"

    $DetailedLog = [System.IO.Path]::Combine($LogFolder, "Robocopy_Detail.log")
    Rotate-SingleLog -LogFilePath $DetailedLog -ArchivePrefix "Robocopy_Detail_"
}



# ====================================================================
# REMOVE OLD LOGS
# ====================================================================

function Cleanup-OldLogs
{
    try
    {
        if (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue)
        {
            Get-ChildItem `
                -Path $LogFolder `
                -Filter "*.log" `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays)
                } |
                Remove-Item `
                    -Force `
                    -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Write-Log "Log Cleanup Error: $_"
    }
}



# ====================================================================
# HELPER FUNCTIONS
# ====================================================================

function Resolve-SourcePath
{
    param(
        [string]$Source
    )

    $Source = if ($Source) { $Source.Trim() } else { "" }

    if ($Source.StartsWith("\\"))
    {
        return $Source.TrimEnd('\', '/')
    }
    elseif (-not [string]::IsNullOrWhiteSpace($SourceServerIP) -and -not [string]::IsNullOrWhiteSpace($SourceShareName))
    {
        if ([string]::IsNullOrWhiteSpace($Source) -or $Source -eq "\" -or $Source -eq "/")
        {
            return "\\$SourceServerIP\$SourceShareName"
        }
        else
        {
            $cleanSub = $Source.TrimStart('\', '/').TrimEnd('\', '/')
            return "\\$SourceServerIP\$SourceShareName\$cleanSub"
        }
    }
    else
    {
        return $Source.TrimEnd('\', '/')
    }
}

function Get-NormalizedFolderMappings
{
    $normalized = [System.Collections.Generic.List[PSObject]]::new()

    if ($FolderMappings -is [System.Collections.IDictionary])
    {
        # Supports dictionary format: @{ "Line1" = "D:\Dest1"; "Line2" = "D:\Dest2" }
        $index = 1
        foreach ($key in $FolderMappings.Keys)
        {
            $val = $FolderMappings[$key]
            if ($val -is [System.Collections.IDictionary])
            {
                $src     = if ($val.ContainsKey('Source')) { $val.Source } else { $key }
                $dst     = if ($val.ContainsKey('Destination')) { $val.Destination } else { "" }
                $enabled = if ($val.ContainsKey('Enabled')) { [bool]$val.Enabled } else { $true }
                $types   = if ($val.ContainsKey('FileTypes')) { $val.FileTypes } else { $FileTypes }
                $name    = if ($val.ContainsKey('Name')) { $val.Name } else { "$key" }
            }
            else
            {
                $src     = $key
                $dst     = $val
                $enabled = $true
                $types   = $FileTypes
                $name    = if ($key) { "$key" } else { "Folder $index" }
            }

            $normalized.Add([PSCustomObject]@{
                Name        = $name
                Source      = [string]$src
                Destination = [string]$dst
                Enabled     = $enabled
                FileTypes   = $types
            })
            $index++
        }
    }
    elseif ($FolderMappings -is [System.Collections.IEnumerable] -and $FolderMappings -isnot [string])
    {
        # Supports array format: @( @{ Source = "Line1"; Destination = "D:\..." }, ... )
        $index = 1
        foreach ($item in $FolderMappings)
        {
            if ($item -is [System.Collections.IDictionary] -or $item -is [PSCustomObject])
            {
                $src     = if ($null -ne $item.Source) { $item.Source } elseif ($null -ne $item.SourceSubFolder) { $item.SourceSubFolder } else { "" }
                $dst     = if ($null -ne $item.Destination) { $item.Destination } elseif ($null -ne $item.DestinationPath) { $item.DestinationPath } else { "" }
                $enabled = if ($null -ne $item.Enabled) { [bool]$item.Enabled } else { $true }
                $types   = if ($item.FileTypes) { $item.FileTypes } else { $FileTypes }
                $name    = if ($item.Name) { $item.Name } elseif ($src) { "$src" } else { "Folder $index" }

                $normalized.Add([PSCustomObject]@{
                    Name        = $name
                    Source      = [string]$src
                    Destination = [string]$dst
                    Enabled     = $enabled
                    FileTypes   = $types
                })
                $index++
            }
        }
    }
    elseif ($DestinationPath)
    {
        # Fallback to legacy single $DestinationPath if defined
        $normalized.Add([PSCustomObject]@{
            Name        = "Default Share"
            Source      = ""
            Destination = $DestinationPath
            Enabled     = $true
            FileTypes   = $FileTypes
        })
    }

    return $normalized.ToArray()
}



# ====================================================================
# CONNECT TO SOURCE SHARE
# ====================================================================

function Connect-SourceShare
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$SharePath
    )

    try
    {
        $UNCPath = $SharePath.Trim().TrimEnd('\', '/')

        # Extract root share (e.g. \\server\share) for net use
        if ($UNCPath.StartsWith("\\"))
        {
            $parts = $UNCPath.TrimStart('\').Split('\')
            if ($parts.Length -ge 2)
            {
                $UNCPath = "\\$($parts[0])\$($parts[1])"
            }
        }

        Write-Log "Connecting to $UNCPath"

        cmd.exe /c "net use `"$UNCPath`" /delete /y" *> $null

        cmd.exe /c "net use `"$UNCPath`" /user:$SourceUsername $SourcePassword /persistent:no" *> $null

        Start-Sleep -Seconds 2

        if (Test-Path -LiteralPath $UNCPath)
        {
            Write-Log "Connection successful to $UNCPath"
            return $true
        }

        Write-Log "Connection failed to $UNCPath"
        return $false
    }
    catch
    {
        Write-Log "Connection Error for $UNCPath : $_"
        return $false
    }
}



# ====================================================================
# RUN ROBOCOPY FOR A SINGLE MAPPING
# ====================================================================

function Start-RobocopyCopy
{
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Mapping
    )

    try
    {
        $SourcePath = Resolve-SourcePath $Mapping.Source
        $DestPath   = $Mapping.Destination.Trim().TrimEnd('\', '/')

        # Ensure destination folder exists
        if (!(Test-Path -LiteralPath $DestPath))
        {
            Write-Log "[$($Mapping.Name)] Creating destination directory: $DestPath"
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
        }

        # Check source path availability
        if (!(Test-Path -LiteralPath $SourcePath))
        {
            Write-Log "[$($Mapping.Name)] WARNING: Source folder not found or inaccessible: $SourcePath"
            return $false
        }

        $activeTypes = if ($Mapping.FileTypes) { $Mapping.FileTypes } else { $FileTypes }
        $DetailedLog = [System.IO.Path]::Combine($LogFolder, "Robocopy_Detail.log")

        Write-Log "[$($Mapping.Name)] Starting Robocopy Sync"
        Write-Log "[$($Mapping.Name)] Source: $SourcePath"
        Write-Log "[$($Mapping.Name)] Dest  : $DestPath"

        # Robocopy command arguments
        $Arguments = @(
            "`"$SourcePath`"",
            "`"$DestPath`""
        )

        foreach ($ft in $activeTypes)
        {
            if ($ft -and $ft.Trim())
            {
                $ft.Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
                    $Arguments += $_
                }
            }
        }

        $Arguments += @(
            "/E",
            "/Z",
            "/FFT",
            "/XO",
            "/R:$RetryAttempts",
            "/W:$RetryWaitSeconds",
            "/NP",
            "/TEE",
            "/LOG+:`"$DetailedLog`""
        )

        $Process = Start-Process `
            -FilePath "robocopy.exe" `
            -ArgumentList $Arguments `
            -Wait `
            -NoNewWindow `
            -PassThru

        $ExitCode = $Process.ExitCode

        $resultMsg = switch ($ExitCode)
        {
            0 { "No changes detected." }
            1 { "Files copied successfully." }
            2 { "Extra files/directories exist at destination." }
            3 { "Files copied and extra destination files detected." }
            4 { "Mismatched files detected." }
            5 { "Files copied with mismatches detected." }
            6 { "Extras and mismatches detected." }
            7 { "Files copied, extras and mismatches detected." }
            Default { "Robocopy warning/error. Exit Code: $ExitCode" }
        }

        if ($ExitCode -le 7)
        {
            Write-Log "[$($Mapping.Name)] Robocopy Result: $resultMsg (Exit Code: $ExitCode)"
            return $true
        }
        else
        {
            Write-Log "[$($Mapping.Name)] Robocopy Failed: $resultMsg (Exit Code: $ExitCode)"
            return $false
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Robocopy Exception: $_"
        return $false
    }
}



# ====================================================================
# RUN REPLICATION CYCLE FOR ALL MAPPINGS
# ====================================================================

function Invoke-Replication
{
    $Mappings = @(Get-NormalizedFolderMappings)

    if ($Mappings.Count -eq 0)
    {
        Write-Log "No folder mappings defined. Please configure `$FolderMappings in the script."
        return
    }

    # Identify all distinct root UNC shares that need connection
    $rootShares = @()
    foreach ($m in $Mappings)
    {
        if ($m.Enabled)
        {
            $src = Resolve-SourcePath $m.Source
            if ($src.StartsWith("\\"))
            {
                $parts = $src.TrimStart('\').Split('\')
                if ($parts.Length -ge 2)
                {
                    $root = "\\$($parts[0])\$($parts[1])"
                    if ($rootShares -notcontains $root)
                    {
                        $rootShares += $root
                    }
                }
            }
        }
    }

    if ($rootShares.Count -eq 0)
    {
        if (-not [string]::IsNullOrWhiteSpace($SourceServerIP) -and -not [string]::IsNullOrWhiteSpace($SourceShareName))
        {
            $rootShares += "\\$SourceServerIP\$SourceShareName"
        }
        else
        {
            Write-Log "ERROR: No remote SMB shares could be detected from `$FolderMappings. Please verify your Source paths."
            return
        }
    }

    # Connect to SMB share(s)
    $connectionFailures = 0
    foreach ($share in $rootShares)
    {
        if (-not (Connect-SourceShare -SharePath $share))
        {
            $connectionFailures++
        }
    }

    if ($connectionFailures -eq $rootShares.Count)
    {
        Write-Log "All source shares are unreachable. Skipping copy cycle."
        return
    }

    # Process each folder mapping
    $successCount = 0
    $failureCount = 0
    $skippedCount = 0

    foreach ($mapping in $Mappings)
    {
        if (-not $mapping.Enabled)
        {
            Write-Log "[$($mapping.Name)] Skipped (Disabled in configuration)"
            $skippedCount++
            continue
        }

        $success = Start-RobocopyCopy -Mapping $mapping
        if ($success)
        {
            $successCount++
        }
        else
        {
            $failureCount++
        }
    }

    Write-Log "Replication Cycle Finished: $successCount succeeded, $failureCount failed, $skippedCount skipped."
}



# ====================================================================
# STARTUP INFORMATION
# ====================================================================

$ConfiguredMappings = @(Get-NormalizedFolderMappings)

# Detect all unique root UNC shares from configured mappings
$DetectedShares = @()
foreach ($m in $ConfiguredMappings)
{
    $src = Resolve-SourcePath $m.Source
    if ($src.StartsWith("\\"))
    {
        $parts = $src.TrimStart('\').Split('\')
        if ($parts.Length -ge 2)
        {
            $root = "\\$($parts[0])\$($parts[1])"
            if ($DetectedShares -notcontains $root)
            {
                $DetectedShares += $root
            }
        }
    }
}

Write-Log "=================================================="
Write-Log "Robocopy Multi-Folder Replication Started"
if ($DetectedShares.Count -gt 0)
{
    Write-Log "Source Share(s)     : $($DetectedShares -join ', ')"
}
elseif (-not [string]::IsNullOrWhiteSpace($SourceShareName))
{
    Write-Log "Source Share        : $SourceShareName"
}
Write-Log "Configured Folders  : $($ConfiguredMappings.Count)"
foreach ($m in $ConfiguredMappings)
{
    $status = if ($m.Enabled) { "ENABLED" } else { "DISABLED" }
    $resolvedSrc = Resolve-SourcePath $m.Source
    Write-Log "  * [$status] $($m.Name)"
    Write-Log "      Source      : $resolvedSrc"
    Write-Log "      Destination : $($m.Destination)"
}
Write-Log "Polling Interval    : $PollingIntervalSec Seconds"
Write-Log "Default File Types  : $($FileTypes -join ', ')"
Write-Log "Max Log Size        : $MaxLogSizeMB MB"
Write-Log "Max Archives        : $MaxArchivedLogs"
Write-Log "Retention Days      : $LogRetentionDays"
Write-Log "=================================================="



# ====================================================================
# MAIN EXECUTION
# ====================================================================

try
{
    Cleanup-OldLogs

    Invoke-Replication
}
catch
{
    Write-Log "Main Execution Error: $_"
}