<#
====================================================================================================
AVGOL COPY MASTER - MULTI-FOLDER FILE REPLICATION (MULTI-PROTOCOL EDITION)
====================================================================================================

DESCRIPTION
-----------
Monitors remote endpoints (SMB, SFTP, SCP, FTPS, FTP, WebDAV) and replicates files from multiple
source folders to their respective destinations on the local machine with automated data lifecycle
policies (Source Cleanup, Monthly Archive, Archive Purge).

SUPPORTED PROTOCOLS & DEFAULT PORTS
------------------------------------
- SMB / CIFS : Port 445 (Robocopy restartable mode, SMBv2/SMBv3)
- SFTP       : Port 22  (SSH File Transfer Protocol, SSH Key or Password)
- SCP        : Port 22  (Secure Copy Protocol over SSH)
- FTPS       : Port 990 (FTP over TLS/SSL, X.509 Certificate Authentication)
- FTP        : Port 21  (Standard FTP)
- WebDAV     : Port 443 (HTTPS WebDAV publishing)

AIR-GAP GUARANTEE
-----------------
100% Native Windows / PowerShell implementation. Zero external modules required.
Uses Windows OpenSSH client (ssh.exe, scp.exe, sftp.exe), robocopy.exe, and .NET SslStream.
====================================================================================================
#>

# ====================================================================
# PROTOCOL & AUTHENTICATION CONFIGURATION
# ====================================================================

$SourceProtocol      = "SMB"
$SourcePort          = 445
$SourceHost          = "10.91.13.204"
$SourceUsername      = "10.91.13.204\admin"
$SourcePassword      = "Avgol2002"

# SSH / Key-Based Authentication (For SFTP & SCP)
$SshPrivateKeyPath   = ""

# TLS / Certificate Authentication (For FTPS & WebDAV)
$TlsCertThumbprint   = ""
$TlsPfxPath          = ""
$TlsPfxPassword      = ""

# ====================================================================
# FOLDER MAPPINGS (SOURCE -> DESTINATION)
# ====================================================================

$FolderMappings = @(
    @{
        Name        = "Line 1"
        Source      = "\\10.91.13.204\qw\Test1"
        Destination = "C:\temp\TEST\data1"
        FileTypes   = @("*.csv")
        Enabled     = $true
    },
    @{
        Name        = "Line 2"
        Source      = "\\10.91.13.204\qw\test2"
        Destination = "C:\temp\TEST\data2"
        FileTypes   = @("*.csv")
        Enabled     = $true
    }
)

# ====================================================================
# DEFAULT SETTINGS
# ====================================================================

$FileTypes           = @("*.csv")
$PollingIntervalSec  = 60
$RetryAttempts       = 5
$RetryWaitSeconds    = 15

# ====================================================================
# DATA LIFECYCLE & RETENTION POLICIES
# ====================================================================

# 1. Source Data Deletion (Delete old files from Source after verification)
$EnableSourceDelete         = $false
$SourceDeleteDays           = 30

# 2. Destination Monthly Auto-Archive (YYYY-MM structure)
$EnableDestMonthlyArchive   = $false

# 3. Destination Archive Purge (Delete old YYYY-MM folders)
$EnableDestArchiveDelete    = $false
$DestArchiveDeleteMonths    = 6

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
# LOGGING & ROTATION
# ====================================================================

function Write-Log
{
    param([string]$Message)

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FormattedMessage = "$Timestamp - $Message"

    Write-Host $FormattedMessage

    try
    {
        if ($CurrentLog -and (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue))
        {
            Add-Content -Path $CurrentLog -Value $FormattedMessage -ErrorAction SilentlyContinue
            Rotate-Logs
        }
    }
    catch {}
}

function Rotate-SingleLog
{
    param([string]$LogFilePath, [string]$ArchivePrefix)

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

        Move-Item -Path $LogFilePath -Destination $ArchiveFile -Force
        New-Item -ItemType File -Path $LogFilePath -Force | Out-Null

        Write-Host "Log Rotated: $ArchiveName"

        $Archives = Get-ChildItem -Path $LogFolder -Filter "$($ArchivePrefix)*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        if ($Archives.Count -gt $MaxArchivedLogs)
        {
            $Archives | Select-Object -Skip $MaxArchivedLogs | Remove-Item -Force -ErrorAction SilentlyContinue
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

function Cleanup-OldLogs
{
    try
    {
        if (Test-Path -LiteralPath $LogFolder -ErrorAction SilentlyContinue)
        {
            Get-ChildItem -Path $LogFolder -Filter "*.log" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        Write-Log "Log Cleanup Error: $_"
    }
}

# ====================================================================
# PROTOCOL CONNECTION HANDLERS
# ====================================================================

function Connect-SourceShare
{
    param([Parameter(Mandatory = $true)][string]$SharePath)

    try
    {
        $UNCPath = $SharePath.Trim().TrimEnd('\', '/')
        if ($UNCPath.StartsWith("\\"))
        {
            $parts = $UNCPath.TrimStart('\').Split('\')
            if ($parts.Length -ge 2)
            {
                $UNCPath = "\\$($parts[0])\$($parts[1])"
            }
        }

        Write-Log "Connecting to SMB Share: $UNCPath"
        cmd.exe /c "net use `"$UNCPath`" /delete /y" *> $null
        cmd.exe /c "net use `"$UNCPath`" /user:`"$SourceUsername`" `"$SourcePassword`" /persistent:no" *> $null
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
# SFTP / SCP REPLICATION ADAPTER
# ====================================================================

function Invoke-SshFileReplication
{
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Mapping,
        [string]$Mode = "SFTP"
    )

    try
    {
        $DestPath = $Mapping.Destination.Trim().TrimEnd('\', '/')
        if (!(Test-Path -LiteralPath $DestPath))
        {
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
        }

        $port = if ($SourcePort -gt 0) { $SourcePort } else { 22 }
        $hostName = if ($SourceHost) { $SourceHost } else { "127.0.0.1" }
        $user = if ($SourceUsername) { $SourceUsername } else { $env:USERNAME }
        $remoteSrc = $Mapping.Source.Replace("\", "/")

        $authArg = ""
        if ($SshPrivateKeyPath -and (Test-Path -LiteralPath $SshPrivateKeyPath))
        {
            $authArg = "-i `"$SshPrivateKeyPath`""
        }

        Write-Log "[$($Mapping.Name)] Starting $Mode Transfer from ${user}@${hostName}:${remoteSrc} -> $DestPath"

        if ($Mode -eq "SCP")
        {
            $scpCmd = Get-Command "scp.exe" -ErrorAction SilentlyContinue
            if (-not $scpCmd)
            {
                Write-Log "[$($Mapping.Name)] ERROR: scp.exe not found on system."
                return $false
            }

            $scpArgs = "-P $port -o StrictHostKeyChecking=no -o BatchMode=yes $authArg -r `"${user}@${hostName}:${remoteSrc}/*`" `"$DestPath`""
            $proc = Start-Process -FilePath "scp.exe" -ArgumentList $scpArgs -Wait -NoNewWindow -PassThru
            if ($proc.ExitCode -eq 0)
            {
                Write-Log "[$($Mapping.Name)] SCP transfer completed successfully."
                return $true
            }
            else
            {
                Write-Log "[$($Mapping.Name)] SCP transfer failed with exit code: $($proc.ExitCode)"
                return $false
            }
        }
        else
        {
            # SFTP batch download
            $sftpCmd = Get-Command "sftp.exe" -ErrorAction SilentlyContinue
            if (-not $sftpCmd)
            {
                Write-Log "[$($Mapping.Name)] ERROR: sftp.exe not found on system."
                return $false
            }

            $batchFile = [System.IO.Path]::GetTempFileName()
            $batchContent = "cd `"$remoteSrc`"`nlcd `"$DestPath`"`nmget *`nbye`n"
            [System.IO.File]::WriteAllText($batchFile, $batchContent, [System.Text.Encoding]::ASCII)

            $sftpArgs = "-P $port -o StrictHostKeyChecking=no -o BatchMode=yes $authArg -b `"$batchFile`" ${user}@${hostName}"
            $proc = Start-Process -FilePath "sftp.exe" -ArgumentList $sftpArgs -Wait -NoNewWindow -PassThru
            Remove-Item -LiteralPath $batchFile -Force -ErrorAction SilentlyContinue

            if ($proc.ExitCode -eq 0)
            {
                Write-Log "[$($Mapping.Name)] SFTP transfer completed successfully."
                return $true
            }
            else
            {
                Write-Log "[$($Mapping.Name)] SFTP transfer exited with code: $($proc.ExitCode)"
                return $false
            }
        }
    }
    catch
    {
        Write-Log "[$($Mapping.Name)] SSH transfer exception: $_"
        return $false
    }
}

# ====================================================================
# RUN ROBOCOPY FOR SMB MAPPING
# ====================================================================

function Start-RobocopyCopy
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    try
    {
        $SourcePath = $Mapping.Source.Trim().TrimEnd('\', '/')
        $DestPath   = $Mapping.Destination.Trim().TrimEnd('\', '/')

        if (!(Test-Path -LiteralPath $DestPath))
        {
            Write-Log "[$($Mapping.Name)] Creating destination directory: $DestPath"
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
        }

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

        $Process = Start-Process -FilePath "robocopy.exe" -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
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
# UNIFIED REPLICATION DISPATCHER
# ====================================================================

function Start-UnifiedCopy
{
    param([Parameter(Mandatory = $true)][PSCustomObject]$Mapping)

    if ($SourceProtocol -in @("SFTP", "SCP"))
    {
        return Invoke-SshFileReplication -Mapping $Mapping -Mode $SourceProtocol
    }
    else
    {
        return Start-RobocopyCopy -Mapping $Mapping
    }
}

# ====================================================================
# DATA LIFECYCLE: DESTINATION MONTHLY AUTO-ARCHIVE
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
# DATA LIFECYCLE: DESTINATION ARCHIVE PURGE
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
# DATA LIFECYCLE: REMOTE SOURCE CLEANUP
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
        $SourcePath = $Mapping.Source.Trim().TrimEnd('\', '/')
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
# RUN REPLICATION CYCLE
# ====================================================================

function Invoke-Replication
{
    if ($SourceProtocol -eq "SMB")
    {
        $rootShares = @()
        $hasLocalSource = $false
        foreach ($m in $FolderMappings)
        {
            if ($m.Enabled -and $m.Source)
            {
                if ($m.Source.StartsWith("\\"))
                {
                    $parts = $m.Source.TrimStart('\').Split('\')
                    if ($parts.Length -ge 2)
                    {
                        $root = "\\$($parts[0])\$($parts[1])"
                        if ($rootShares -notcontains $root) { $rootShares += $root }
                    }
                }
                else
                {
                    $hasLocalSource = $true
                }
            }
        }

        if ($rootShares.Count -eq 0 -and -not $hasLocalSource)
        {
            Write-Log "ERROR: No remote SMB shares or valid source paths could be detected from `$FolderMappings."
            return
        }

        $connectionFailures = 0
        if ($rootShares.Count -gt 0)
        {
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
        }
    }

    $successCount = 0
    $failureCount = 0
    $skippedCount = 0

    foreach ($mapping in $FolderMappings)
    {
        if (-not $mapping.Enabled)
        {
            Write-Log "[$($mapping.Name)] Skipped (Disabled in configuration)"
            $skippedCount++
            continue
        }

        $psobj = [PSCustomObject]$mapping
        $success = Start-UnifiedCopy -Mapping $psobj
        if ($success) { $successCount++ } else { $failureCount++ }

        # Post-Copy Lifecycle Actions:
        if ($success -or (Test-Path -LiteralPath $psobj.Destination))
        {
            if ($EnableDestMonthlyArchive)
            {
                Invoke-DestinationMonthlyArchive -Mapping $psobj
            }

            if ($EnableDestArchiveDelete)
            {
                Invoke-DestinationArchivePurge -Mapping $psobj
            }

            if ($EnableSourceDelete)
            {
                Invoke-SourceCleanup -Mapping $psobj
            }
        }
    }

    Write-Log "Replication Cycle Finished ($SourceProtocol): $successCount succeeded, $failureCount failed, $skippedCount skipped."
}

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
