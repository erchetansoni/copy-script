@echo off
setlocal EnableDelayedExpansion

:: ====================================================================
:: EVS Replication Configurator Launcher
:: ====================================================================

:: Check for Administrative privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: Switch to script directory
cd /d "%~dp0"
title EVS File Replication Configurator

echo ====================================================================
echo Starting EVS File Replication Configurator GUI...
echo ====================================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Configure-ReplicationUI.ps1"

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] An error occurred while launching the configurator.
    pause
)
