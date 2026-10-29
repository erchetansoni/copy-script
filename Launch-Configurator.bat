@echo off
setlocal EnableDelayedExpansion

:: ====================================================================
:: Avgol Copy Master Launcher
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
title Avgol Copy Master

echo ====================================================================
echo Starting Avgol Copy Master GUI...
echo ====================================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Configure-ReplicationUI.ps1"

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] An error occurred while launching the configurator.
    pause
)
