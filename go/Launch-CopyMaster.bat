@echo off
setlocal
cd /d "%~dp0"
title Copy Master - Industrial Multi-Protocol Replication Suite

echo ====================================================================
echo Starting Copy Master Air-Gapped Terminal UI...
echo ====================================================================

if not exist "bin\copymaster.exe" (
    echo [INFO] bin\copymaster.exe not found.
    echo Compiling standalone binary with Build-Binaries.ps1...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build\Build-Binaries.ps1"
)

if exist "bin\copymaster.exe" (
    "%~dp0bin\copymaster.exe"
) else (
    echo [ERROR] Failed to compile or locate bin\copymaster.exe.
    pause
)
