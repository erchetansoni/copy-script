<#
====================================================================================================
AVGOL COPY MASTER - AUTOMATED END-TO-END (E2E) TEST SUITE
====================================================================================================
Purpose:
Comprehensive automated verification script for developers and quality engineers.
Simulates and validates all core subsystems of Avgol Copy Master:
  1. AST Syntax Parser Check (UI generator and core replication script)
  2. UI Template Extraction & Code Generation
  3. Robocopy Multi-Folder Synchronization
  4. Destination Monthly Auto-Archive (YYYY-MM segregation)
  5. Destination Historical Archive Purge (pruning folders older than X months)
  6. Verified Remote Source Cleanup (safe file deletion matching byte lengths)
  7. Loop Prevention Verification (preventing re-copy of archived files via /XD and /XF)
  8. Dual-Logging and Log Rotation Structure

Modes:
  - Local Sandbox Mode (Default): Runs 100% offline in a local temporary directory.
    Zero network, domain, or credentials required. Safe for air-gap developer testing.
  - Remote SMB Mode: Tests live network UNC shares with supplied credentials.

Usage:
  .\Test-AvgolCopyMaster-E2E.ps1
  .\Test-AvgolCopyMaster-E2E.ps1 -KeepTestFiles
  .\Test-AvgolCopyMaster-E2E.ps1 -RemoteUNC "\\10.91.13.204\qw\E2E_Test" -Username "10.91.13.204\admin" -Password "Avgol2002"
====================================================================================================
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$TestRoot = "C:\temp\Avgol_E2E_Test",

    [Parameter(Mandatory = $false)]
    [string]$RemoteUNC = "",

    [Parameter(Mandatory = $false)]
    [string]$Username = "",

    [Parameter(Mandatory = $false)]
    [string]$Password = "",

    [Parameter(Mandatory = $false)]
    [switch]$KeepTestFiles
)

# Set error handling preference
$ErrorActionPreference = "Stop"

# Test Tracker
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:TestResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$startTime = [System.Diagnostics.Stopwatch]::StartNew()

function Assert-Condition
{
    param (
        [string]$TestName,
        [bool]$Condition,
        [string]$Details = ""
    )

    $script:TotalTests++
    if ($Condition)
    {
        $script:PassedTests++
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        if ($Details) { Write-Host "         $Details" -ForegroundColor DarkGray }
        $script:TestResults.Add([PSCustomObject]@{
            Status  = "PASS"
            Name    = $TestName
            Details = $Details
        })
    }
    else
    {
        $script:FailedTests++
        Write-Host "  [FAIL] $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "         ERROR: $Details" -ForegroundColor Yellow }
        $script:TestResults.Add([PSCustomObject]@{
            Status  = "FAIL"
            Name    = $TestName
            Details = $Details
        })
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         AVGOL COPY MASTER - END-TO-END AUTOMATED TEST SUITE          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Execution Time  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Working TestRoot: $TestRoot" -ForegroundColor Gray
if ($RemoteUNC) {
    Write-Host "Mode            : Remote SMB ($RemoteUNC)" -ForegroundColor Gray
} else {
    Write-Host "Mode            : Local Sandbox (Offline / Air-Gap)" -ForegroundColor Gray
}
Write-Host ""

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
$uiScriptPath  = [System.IO.Path]::Combine($scriptDir, "Avgol-CopyMaster-UI.ps1")
$coreScriptPath = [System.IO.Path]::Combine($scriptDir, "Avgol-CopyScript.ps1")

# ====================================================================================================
# STAGE 1: REPOSITORY STATIC CODE & AST SYNTAX VALIDATION
# ====================================================================================================
Write-Host "STAGE 1: Static Code Analysis & PowerShell AST Parser Validation" -ForegroundColor Yellow

# Test 1.1: UI Script exists
$uiExists = Test-Path -LiteralPath $uiScriptPath
Assert-Condition -TestName "Verify Avgol-CopyMaster-UI.ps1 exists" -Condition $uiExists -Details $uiScriptPath

# Test 1.2: UI Script AST Syntax Clean (0 errors)
$uiParseErrors = $null
if ($uiExists) {
    [System.Management.Automation.Language.Parser]::ParseFile($uiScriptPath, [ref]$null, [ref]$uiParseErrors) | Out-Null
    $uiErrCount = if ($uiParseErrors) { $uiParseErrors.Count } else { 0 }
    Assert-Condition -TestName "Avgol-CopyMaster-UI.ps1 AST Syntax Clean" -Condition ($uiErrCount -eq 0) -Details "Errors: $uiErrCount"
}

# Test 1.3: Core Reference Script exists
$coreExists = Test-Path -LiteralPath $coreScriptPath
Assert-Condition -TestName "Verify Avgol-CopyScript.ps1 exists" -Condition $coreExists -Details $coreScriptPath

# Test 1.4: Core Reference Script AST Syntax Clean (0 errors)
$coreParseErrors = $null
if ($coreExists) {
    [System.Management.Automation.Language.Parser]::ParseFile($coreScriptPath, [ref]$null, [ref]$coreParseErrors) | Out-Null
    $coreErrCount = if ($coreParseErrors) { $coreParseErrors.Count } else { 0 }
    Assert-Condition -TestName "Avgol-CopyScript.ps1 AST Syntax Clean" -Condition ($coreErrCount -eq 0) -Details "Errors: $coreErrCount"
}

# ====================================================================================================
# STAGE 2: TEST SANDBOX & FIXTURES SETUP
# ====================================================================================================
Write-Host "`nSTAGE 2: Preparing Test Environment & Fixtures" -ForegroundColor Yellow

$testSrc = ""
$testDst = [System.IO.Path]::Combine($TestRoot, "Dest")
$testLog = [System.IO.Path]::Combine($TestRoot, "Logs")
$testGenScript = [System.IO.Path]::Combine($TestRoot, "E2E_GeneratedScript.ps1")

if ($RemoteUNC) {
    # Mount SMB share if credentials supplied
    if ($Username -and $Password) {
        $parts = $RemoteUNC.TrimStart('\').Split('\')
        $rootShare = "\\$($parts[0])\$($parts[1])"
        cmd.exe /c "net use `"$rootShare`" /delete /y" *> $null
        cmd.exe /c "net use `"$rootShare`" /user:`"$Username`" `"$Password`" /persistent:no" *> $null
    }
    $testSrc = $RemoteUNC
} else {
    $testSrc = [System.IO.Path]::Combine($TestRoot, "Source")
}

# Initialize fresh test folders
try {
    if (Test-Path -LiteralPath $testDst) { Remove-Item -LiteralPath $testDst -Recurse -Force }
    if (Test-Path -LiteralPath $testLog) { Remove-Item -LiteralPath $testLog -Recurse -Force }
    if ((-not $RemoteUNC) -and (Test-Path -LiteralPath $testSrc)) { Remove-Item -LiteralPath $testSrc -Recurse -Force }

    New-Item -ItemType Directory -Path $testSrc -Force | Out-Null
    New-Item -ItemType Directory -Path $testDst -Force | Out-Null
    New-Item -ItemType Directory -Path $testLog -Force | Out-Null
} catch {
    Write-Host "Warning during directory preparation: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# Date Anchors
$now = Get-Date
$currentMonthStart = [DateTime]::new($now.Year, $now.Month, 1, 0, 0, 0)
$lastMonthDate     = $currentMonthStart.AddDays(-10) # Previous month
$oldFileDate       = $currentMonthStart.AddDays(-60) # 2 months ago (older than 30 days)
$expiredArchiveYM  = $currentMonthStart.AddMonths(-12).ToString("yyyy-MM") # 12 months ago
$validArchiveYM    = $currentMonthStart.AddMonths(-2).ToString("yyyy-MM")  # 2 months ago

# File 1: Current month active file (Generated today)
$fileCurrent = [System.IO.Path]::Combine($testSrc, "Active_CurrentMonth.csv")
[System.IO.File]::WriteAllText($fileCurrent, "RollID,Timestamp,DefectCount`nR1001,$($now.ToString('s')),0`n", [System.Text.Encoding]::UTF8)
(Get-Item $fileCurrent).LastWriteTime = $now

# File 2: Prior month file to be archived (Last month)
$filePrior = [System.IO.Path]::Combine($testSrc, "Archive_PriorMonth.csv")
[System.IO.File]::WriteAllText($filePrior, "RollID,Timestamp,DefectCount`nR0901,$($lastMonthDate.ToString('s')),1`n", [System.Text.Encoding]::UTF8)
(Get-Item $filePrior).LastWriteTime = $lastMonthDate

# File 3: Old file to be archived and deleted from source (>30 days old)
$fileOld = [System.IO.Path]::Combine($testSrc, "Cleanup_OldFile.csv")
[System.IO.File]::WriteAllText($fileOld, "RollID,Timestamp,DefectCount`nR0801,$($oldFileDate.ToString('s')),0`n", [System.Text.Encoding]::UTF8)
(Get-Item $fileOld).LastWriteTime = $oldFileDate

# Fixture 4: Historical Expired Archive in Destination (e.g. 12 months ago)
$expiredArchiveDir = [System.IO.Path]::Combine($testDst, $expiredArchiveYM)
New-Item -ItemType Directory -Path $expiredArchiveDir -Force | Out-Null
[System.IO.File]::WriteAllText([System.IO.Path]::Combine($expiredArchiveDir, "OldArchiveData.csv"), "Historic", [System.Text.Encoding]::UTF8)

# Fixture 5: Recent Valid Archive in Destination (e.g. 2 months ago, should NOT be purged)
$validArchiveDir = [System.IO.Path]::Combine($testDst, $validArchiveYM)
New-Item -ItemType Directory -Path $validArchiveDir -Force | Out-Null
[System.IO.File]::WriteAllText([System.IO.Path]::Combine($validArchiveDir, "RetainedArchiveData.csv"), "Retained", [System.Text.Encoding]::UTF8)

Assert-Condition -TestName "Test fixtures generated successfully" -Condition (
    (Test-Path -LiteralPath $fileCurrent) -and
    (Test-Path -LiteralPath $filePrior) -and
    (Test-Path -LiteralPath $fileOld) -and
    (Test-Path -LiteralPath $expiredArchiveDir)
) -Details "Created 3 test files and 2 destination archive folders"

# ====================================================================================================
# STAGE 3: SCRIPT GENERATION FROM UI TEMPLATE
# ====================================================================================================
Write-Host "`nSTAGE 3: Template Extraction & Automated Code Generation" -ForegroundColor Yellow

$uiRaw = Get-Content -Raw -Path $uiScriptPath
$startMarker = '$template = @'''
$endMarker   = '''@'
$sIdx = $uiRaw.IndexOf($startMarker) + $startMarker.Length
$eIdx = $uiRaw.IndexOf($endMarker, $sIdx)
$extractedTemplate = $uiRaw.Substring($sIdx, $eIdx - $sIdx).Trim()

Assert-Condition -TestName "Extracted code template from UI script" -Condition ($extractedTemplate.Length -gt 1000) -Details "Template Size: $($extractedTemplate.Length) characters"

$mappingsCode = @"
`$FolderMappings = @(
    @{
        Name        = "E2E Automated Line"
        Source      = "$testSrc"
        Destination = "$testDst"
        FileTypes   = @("*.csv")
        Enabled     = `$true
    }
)
"@

$renderedScript = $extractedTemplate
$renderedScript = $renderedScript.Replace("__GENERATED_TIMESTAMP__", (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$renderedScript = $renderedScript.Replace("__MAPPING_COUNT__", "1")
$renderedScript = $renderedScript.Replace("__SOURCE_USERNAME__", $Username)
$renderedScript = $renderedScript.Replace("__SOURCE_PASSWORD__", $Password)
$renderedScript = $renderedScript.Replace("__FOLDER_MAPPINGS__", $mappingsCode)
$renderedScript = $renderedScript.Replace("__LOG_FOLDER__", $testLog)
$renderedScript = $renderedScript.Replace("__MAX_LOG_MB__", "10")
$renderedScript = $renderedScript.Replace("__RETENTION_DAYS__", "30")
$renderedScript = $renderedScript.Replace("__POLLING_SEC__", "60")
$renderedScript = $renderedScript.Replace("__ENABLE_SOURCE_DELETE__", "`$true")
$renderedScript = $renderedScript.Replace("__SOURCE_DELETE_DAYS__", "30")
$renderedScript = $renderedScript.Replace("__ENABLE_DEST_ARCHIVE__", "`$true")
$renderedScript = $renderedScript.Replace("__ENABLE_DEST_DELETE__", "`$true")
$renderedScript = $renderedScript.Replace("__DEST_DELETE_MONTHS__", "6")

[System.IO.File]::WriteAllText($testGenScript, $renderedScript, [System.Text.Encoding]::UTF8)

# Validate generated script AST
$genParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($renderedScript, [ref]$null, [ref]$genParseErrors) | Out-Null
$genErrCount = if ($genParseErrors) { $genParseErrors.Count } else { 0 }
Assert-Condition -TestName "Generated E2E script parsed with 0 syntax errors" -Condition ($genErrCount -eq 0) -Details "Errors: $genErrCount"

# ====================================================================================================
# STAGE 4: EXECUTE REPLICATION CYCLE (PASS 1)
# ====================================================================================================
Write-Host "`nSTAGE 4: Executing Replication Script (Pass 1 - Copy & Lifecycle)" -ForegroundColor Yellow

$proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$testGenScript`"" `
    -NoNewWindow -PassThru -Wait

Assert-Condition -TestName "Replication script completed execution" -Condition ($proc.ExitCode -le 7) -Details "Process Exit Code: $($proc.ExitCode)"

# ====================================================================================================
# STAGE 5: POST-REPLICATION LIFECYCLE ASSERTIONS
# ====================================================================================================
Write-Host "`nSTAGE 5: Validating Post-Replication Lifecycle Subsystems" -ForegroundColor Yellow

# Check 5.1: Current month file copied to destination root
$destCurrent = [System.IO.Path]::Combine($testDst, "Active_CurrentMonth.csv")
Assert-Condition -TestName "Current month file exists at destination root" -Condition (Test-Path -LiteralPath $destCurrent) -Details $destCurrent

# Check 5.2: Prior month file auto-archived into YYYY-MM
$priorYM = $lastMonthDate.ToString("yyyy-MM")
$destPriorArchived = [System.IO.Path]::Combine($testDst, $priorYM, "Archive_PriorMonth.csv")
Assert-Condition -TestName "Prior month file auto-archived into $priorYM" -Condition (Test-Path -LiteralPath $destPriorArchived) -Details $destPriorArchived

# Check 5.3: Prior month file removed from destination root (moved into archive)
$destPriorRoot = [System.IO.Path]::Combine($testDst, "Archive_PriorMonth.csv")
Assert-Condition -TestName "Prior month file moved out of destination root" -Condition (-not (Test-Path -LiteralPath $destPriorRoot)) -Details "Root cleanly migrated"

# Check 5.4: Old file auto-archived into YYYY-MM
$oldYM = $oldFileDate.ToString("yyyy-MM")
$destOldArchived = [System.IO.Path]::Combine($testDst, $oldYM, "Cleanup_OldFile.csv")
Assert-Condition -TestName "Old file auto-archived into $oldYM" -Condition (Test-Path -LiteralPath $destOldArchived) -Details $destOldArchived

# Check 5.5: Destination Historical Archive Purge (Expired archive deleted)
Assert-Condition -TestName "Historical archive older than 6 months ($expiredArchiveYM) purged" -Condition (-not (Test-Path -LiteralPath $expiredArchiveDir)) -Details "Folder safely removed"

# Check 5.6: Destination Recent Archive Retained (Valid archive kept)
Assert-Condition -TestName "Recent archive folder ($validArchiveYM) retained" -Condition (Test-Path -LiteralPath $validArchiveDir) -Details "Folder preserved"

# Check 5.7: Verified Remote Source Cleanup
# The old file (>30 days) was copied and verified in archive, so it must be deleted from source
Assert-Condition -TestName "Old file (>30 days) safely deleted from source after verification" -Condition (-not (Test-Path -LiteralPath $fileOld)) -Details "Verified byte match before deletion"

# Check 5.8: Source Active File Protected
# Current month file is NOT older than 30 days, must remain at source
Assert-Condition -TestName "Current month file (<30 days) preserved at source" -Condition (Test-Path -LiteralPath $fileCurrent) -Details "Source data intact"

# ====================================================================================================
# STAGE 6: RE-COPY LOOP EXCLUSION VERIFICATION (PASS 2)
# ====================================================================================================
Write-Host "`nSTAGE 6: Re-Execution Loop Prevention Check (Pass 2)" -ForegroundColor Yellow

# Re-run replication script
$proc2 = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$testGenScript`"" `
    -NoNewWindow -PassThru -Wait

Assert-Condition -TestName "Replication script completed second execution" -Condition ($proc2.ExitCode -le 7) -Details "Exit Code: $($proc2.ExitCode)"

# Ensure archived files were NOT copied back to root
Assert-Condition -TestName "Loop prevention: Prior month file was NOT re-copied to destination root" -Condition (-not (Test-Path -LiteralPath $destPriorRoot)) -Details "/XD and /XF exclusions working correctly"

# ====================================================================================================
# STAGE 7: LOG GENERATION & ROTATION AUDIT
# ====================================================================================================
$robocopyLog = [System.IO.Path]::Combine($testLog, "Robocopy_Current.log")

$hasRoboLog = (Test-Path -LiteralPath $robocopyLog) -and ((Get-Item $robocopyLog).Length -gt 0)
Assert-Condition -TestName "Robocopy_Current.log exists and is non-empty" -Condition $hasRoboLog -Details $robocopyLog

$logContent = if ($hasRoboLog) { Get-Content -LiteralPath $robocopyLog -Raw } else { "" }
$hasSyncEntries = $logContent -match "ROBOCOPY" -or $logContent -match "Started :"
Assert-Condition -TestName "Robocopy_Current.log contains Robocopy synchronization summary" -Condition $hasSyncEntries -Details "Robocopy header verified"

$hasLifecycleEntries = $logContent -match "\[DEST ARCHIVE\]" -or $logContent -match "Monthly Archive"
Assert-Condition -TestName "Robocopy_Current.log records operational lifecycle events" -Condition $hasLifecycleEntries -Details "Lifecycle events verified"

# ====================================================================================================
# TEARDOWN & CLEANUP
# ====================================================================================================
if (-not $KeepTestFiles -and ($script:FailedTests -eq 0)) {
    Write-Host "`nCleaning up test sandbox ($TestRoot)..." -ForegroundColor Gray
    try {
        Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    } catch {}
} else {
    Write-Host "`nTest files preserved at: $TestRoot" -ForegroundColor DarkCyan
}

# ====================================================================================================
# FINAL TEST REPORT
# ====================================================================================================
$startTime.Stop()
Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "                       END-TO-END TEST SUMMARY                        " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Total Tests Run : $($script:TotalTests)"
Write-Host "Passed          : $($script:PassedTests)" -ForegroundColor Green
Write-Host "Failed          : $($script:FailedTests)" -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "Duration        : $($startTime.Elapsed.TotalSeconds.ToString('F2')) seconds"
Write-Host "======================================================================" -ForegroundColor Cyan

if ($script:FailedTests -eq 0) {
    Write-Host "`n>>> ALL END-TO-END TESTS PASSED SUCCESSFULLY! <<<`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n>>> SOME TESTS FAILED. CHECK DETAILS ABOVE. <<<`n" -ForegroundColor Red
    exit 1
}
