<#
====================================================================================================
COPY MASTER - STANDALONE BINARY BUILDER (WINDOWS & LINUX CROSS-COMPILER)
====================================================================================================
Generates 100% self-contained, statically linked standalone executables with embedded PE metadata.
EDR-Safe: Standard Windows PE VersionInfo, Application Manifest, uncompressed (no UPX).
====================================================================================================
#>

param(
    [string]$Version = "2.0.0",
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptDir
Set-Location $RootDir

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       COPY MASTER - NATIVE CROSS-PLATFORM BUILD PIPELINE             " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Target Version: $Version" -ForegroundColor Gray
Write-Host "Project Root  : $RootDir" -ForegroundColor Gray

# Create output directory
$binDir = Join-Path $RootDir "bin"
if (!(Test-Path -LiteralPath $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

# Run Tests if not skipped
if (-not $SkipTests) {
    Write-Host "`n>>> Running Go Test Suite..." -ForegroundColor Yellow
    $tmpDir = Join-Path $RootDir ".gotmp"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $env:GOTMPDIR = (Resolve-Path $tmpDir).Path
    try {
        go test ./...
        if ($LASTEXITCODE -ne 0) {
            throw "Unit/Integration tests failed!"
        }
        Write-Host "All tests passed successfully!" -ForegroundColor Green
    }
    finally {
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
        Remove-Item Env:GOTMPDIR -ErrorAction SilentlyContinue
    }
}

$buildDate = (Get-Date -Format "yyyy-MM-dd")
$ldflags = "-s -w -X main.Version=$Version -X main.BuildDate=$buildDate"

# 1. Build Windows 64-bit Standalone Executable
Write-Host "`n>>> Compiling Windows 64-bit Binary (bin/copymaster.exe)..." -ForegroundColor Yellow
$env:GOOS = "windows"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "0"

go build -ldflags $ldflags -o (Join-Path $binDir "copymaster.exe") ./cmd/copymaster
if ($LASTEXITCODE -ne 0) { throw "Windows build failed!" }

$winItem = Get-Item (Join-Path $binDir "copymaster.exe")
Write-Host "Windows Binary Built: $($winItem.FullName) ($([Math]::Round($winItem.Length/1MB, 2)) MB)" -ForegroundColor Green

# 2. Build Linux 64-bit Standalone Executable (Static, no glibc dependency)
Write-Host "`n>>> Compiling Linux 64-bit Binary (bin/copymaster-linux-amd64)..." -ForegroundColor Yellow
$env:GOOS = "linux"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "0"

go build -ldflags $ldflags -o (Join-Path $binDir "copymaster-linux-amd64") ./cmd/copymaster
if ($LASTEXITCODE -ne 0) { throw "Linux amd64 build failed!" }

$linuxItem = Get-Item (Join-Path $binDir "copymaster-linux-amd64")
Write-Host "Linux amd64 Binary Built: $($linuxItem.FullName) ($([Math]::Round($linuxItem.Length/1MB, 2)) MB)" -ForegroundColor Green

# 3. Build Linux ARM64 Standalone Executable (AWS Graviton, Raspberry Pi, etc.)
Write-Host "`n>>> Compiling Linux ARM64 Binary (bin/copymaster-linux-arm64)..." -ForegroundColor Yellow
$env:GOOS = "linux"
$env:GOARCH = "arm64"
$env:CGO_ENABLED = "0"

go build -ldflags $ldflags -o (Join-Path $binDir "copymaster-linux-arm64") ./cmd/copymaster
if ($LASTEXITCODE -ne 0) { throw "Linux arm64 build failed!" }

$armItem = Get-Item (Join-Path $binDir "copymaster-linux-arm64")
Write-Host "Linux arm64 Binary Built: $($armItem.FullName) ($([Math]::Round($armItem.Length/1MB, 2)) MB)" -ForegroundColor Green

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host ">>> BUILD COMPLETED SUCCESSFULLY! ALL BINARIES READY IN bin/ <<<" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan
