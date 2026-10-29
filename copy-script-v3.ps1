<#
====================================================================================================
AVGOL COPY MASTER - MULTI-FOLDER FILE REPLICATION
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
# DATA LIFECYCLE & RETENTION POLICIES
# ====================================================================

# 1. Source Data Deletion (Delete old files from Source)
$EnableSourceDelete         = $false
$SourceDeleteDays           = 30

# 2. Destination Monthly Auto-Archive (YYYY-MM structure)
$EnableDestMonthlyArchive   = $false

# 3. Destination Archive Purge (Delete old YYYY-MM folders)
$EnableDestArchiveDelete    = $false
$DestArchiveDeleteMonths    = 6

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
            "/LOG+:`"$DetailedLog`"",
            "/XD",
            "20*"
        )

        # Exclude source files from re-copying if already archived into monthly subfolders
        if ($EnableDestMonthlyArchive)
        {
            $now = Get-Date
            $curMonthStart = [DateTime]::new($now.Year, $now.Month, 1, 0, 0, 0)
            $srcFiles = Get-ChildItem -LiteralPath $SourcePath -File -ErrorAction SilentlyContinue
            $xfList = @()
            foreach ($sf in $srcFiles)
            {
                if ($sf.LastWriteTime -lt $curMonthStart)
                {
                    $ym = $sf.LastWriteTime.ToString("yyyy-MM")
                    $archPath = [System.IO.Path]::Combine($DestPath, $ym, $sf.Name)
                    if (Test-Path -LiteralPath $archPath)
                    {
                        $xfList += $sf.Name
                    }
                }
            }
            if ($xfList.Count -gt 0)
            {
                $Arguments += "/XF"
                foreach ($xf in $xfList)
                {
                    $Arguments += $xf
                }
            }
        }

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
# DESTINATION MONTHLY AUTO-ARCHIVE
# ====================================================================

function Invoke-DestinationMonthlyArchive
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if (-not $EnableDestMonthlyArchive)
    {
        return
    }

    try
    {
        $DestPath = $Mapping.Destination.Trim().TrimEnd('\', '/')
        if (!(Test-Path -LiteralPath $DestPath))
        {
            return
        }

        # Any file modified prior to the 1st of current month belongs to previous month
        $now = Get-Date
        $currentMonthStart = [DateTime]::new($now.Year, $now.Month, 1, 0, 0, 0)

        $destFiles = Get-ChildItem -LiteralPath $DestPath -File -ErrorAction SilentlyContinue
        $activeTypes = if ($Mapping.FileTypes) { $Mapping.FileTypes } else { $FileTypes }

        $archivedCount = 0

        foreach ($df in $destFiles)
        {
            $matchesType = $false
            foreach ($pattern in $activeTypes)
            {
                if ($df.Name -like $pattern) { $matchesType = $true; break }
            }
            if (-not $matchesType) { continue }

            if ($df.LastWriteTime -lt $currentMonthStart)
            {
                $ym = $df.LastWriteTime.ToString("yyyy-MM")
                $targetDir = [System.IO.Path]::Combine($DestPath, $ym)

                if (!(Test-Path -LiteralPath $targetDir))
                {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                    Write-Log "[$($Mapping.Name)] Created monthly archive folder: $ym"
                }

                $targetFilePath = [System.IO.Path]::Combine($targetDir, $df.Name)
                Move-Item -LiteralPath $df.FullName -Destination $targetFilePath -Force
                Write-Log "[$($Mapping.Name)] [DEST ARCHIVE] Moved '$($df.Name)' (Modified: $($df.LastWriteTime.ToString('yyyy-MM-dd'))) -> '$ym\'"
                $archivedCount++
            }
        }

        if ($archivedCount -gt 0)
        {
            Write-Log "[$($Mapping.Name)] Monthly Archive: $archivedCount file(s) moved to YYYY-MM archive folders."
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Destination Monthly Archive Error: $_"
    }
}

# ====================================================================
# DESTINATION ARCHIVE PURGE (DELETE OLD MONTHLY FOLDERS)
# ====================================================================

function Invoke-DestinationArchivePurge
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if (-not $EnableDestArchiveDelete -or $DestArchiveDeleteMonths -lt 1)
    {
        return
    }

    try
    {
        $DestPath = $Mapping.Destination.Trim().TrimEnd('\', '/')
        if (!(Test-Path -LiteralPath $DestPath))
        {
            return
        }

        $now = Get-Date
        $currentMonthStart = [DateTime]::new($now.Year, $now.Month, 1, 0, 0, 0)
        $cutoffMonth = $currentMonthStart.AddMonths(-$DestArchiveDeleteMonths)

        $monthFolders = Get-ChildItem -LiteralPath $DestPath -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{4}-(0[1-9]|1[0-2])$' }

        $purgedCount = 0

        foreach ($mf in $monthFolders)
        {
            try
            {
                $folderDate = [DateTime]::ParseExact($mf.Name, "yyyy-MM", [System.Globalization.CultureInfo]::InvariantCulture)
                if ($folderDate -lt $cutoffMonth)
                {
                    Write-Log "[$($Mapping.Name)] [DEST PURGE] Permanently deleting expired archive folder: $($mf.Name) (Cutoff: $($cutoffMonth.ToString('yyyy-MM')))"
                    Remove-Item -LiteralPath $mf.FullName -Recurse -Force -ErrorAction Stop
                    $purgedCount++
                }
            }
            catch
            {
                Write-Log "[$($Mapping.Name)] [DEST PURGE ERROR] Failed removing $($mf.Name): $_"
            }
        }

        if ($purgedCount -gt 0)
        {
            Write-Log "[$($Mapping.Name)] Destination Purge: $purgedCount old monthly archive folder(s) removed."
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Destination Archive Purge Error: $_"
    }
}

# ====================================================================
# REMOTE SOURCE CLEANUP (DELETE OLD SOURCE FILES)
# ====================================================================

function Invoke-SourceCleanup
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if (-not $EnableSourceDelete -or $SourceDeleteDays -lt 1)
    {
        return
    }

    try
    {
        $SourcePath = Resolve-SourcePath $Mapping.Source
        $DestPath   = $Mapping.Destination.Trim().TrimEnd('\', '/')

        if (!(Test-Path -LiteralPath $SourcePath))
        {
            return
        }

        $cutoff = (Get-Date).AddDays(-$SourceDeleteDays)
        $activeTypes = if ($Mapping.FileTypes) { $Mapping.FileTypes } else { $FileTypes }

        Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP] Checking for source files older than $SourceDeleteDays days (Cutoff: $($cutoff.ToString('yyyy-MM-dd HH:mm')))..."

        $sourceFiles = Get-ChildItem -LiteralPath $SourcePath -File -ErrorAction SilentlyContinue

        $deletedCount = 0
        $skippedCount = 0

        foreach ($sf in $sourceFiles)
        {
            $matchesType = $false
            foreach ($pattern in $activeTypes)
            {
                if ($sf.Name -like $pattern) { $matchesType = $true; break }
            }
            if (-not $matchesType) { continue }

            if ($sf.LastWriteTime -lt $cutoff)
            {
                # Verification: verify file exists at destination (root or monthly archive) with matching size
                $destRootFile = [System.IO.Path]::Combine($DestPath, $sf.Name)
                $ym = $sf.LastWriteTime.ToString("yyyy-MM")
                $destArchFile = [System.IO.Path]::Combine($DestPath, $ym, $sf.Name)

                $verified = $false
                if (Test-Path -LiteralPath $destRootFile)
                {
                    $df = Get-Item -LiteralPath $destRootFile -ErrorAction SilentlyContinue
                    if ($df -and $df.Length -eq $sf.Length) { $verified = $true }
                }
                elseif (Test-Path -LiteralPath $destArchFile)
                {
                    $af = Get-Item -LiteralPath $destArchFile -ErrorAction SilentlyContinue
                    if ($af -and $af.Length -eq $sf.Length) { $verified = $true }
                }

                if ($verified)
                {
                    try
                    {
                        Remove-Item -LiteralPath $sf.FullName -Force -ErrorAction Stop
                        Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP] Deleted verified source file: $($sf.Name) (Modified: $($sf.LastWriteTime.ToString('yyyy-MM-dd')))"
                        $deletedCount++
                    }
                    catch
                    {
                        Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP ERROR] Failed to delete $($sf.Name): $_"
                    }
                }
                else
                {
                    Write-Log "[$($Mapping.Name)] [SOURCE CLEANUP] SKIPPED: $($sf.Name) is older than $SourceDeleteDays days but is NOT yet verified at destination."
                    $skippedCount++
                }
            }
        }

        if ($deletedCount -gt 0 -or $skippedCount -gt 0)
        {
            Write-Log "[$($Mapping.Name)] Source Cleanup: $deletedCount deleted, $skippedCount unverified."
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] Source Cleanup Error: $_"
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

        # Post-Copy Lifecycle Actions:
        $destDir = $mapping.Destination.Trim().TrimEnd('\', '/')
        if ($success -or (Test-Path -LiteralPath $destDir))
        {
            # 1. Destination Monthly Auto-Archive (YYYY-MM structure)
            if ($EnableDestMonthlyArchive)
            {
                Invoke-DestinationMonthlyArchive -Mapping $mapping
            }

            # 2. Destination Archive Purge (Delete old YYYY-MM folders)
            if ($EnableDestArchiveDelete)
            {
                Invoke-DestinationArchivePurge -Mapping $mapping
            }

            # 3. Source File Cleanup (Delete verified source files older than X days)
            if ($EnableSourceDelete)
            {
                Invoke-SourceCleanup -Mapping $mapping
            }
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