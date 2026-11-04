@echo off
setlocal
cd /d "%~dp0"
title Copy Master Suite Launcher

echo ====================================================================
echo                   COPY MASTER REPLICATION SUITE
echo ====================================================================
echo.
echo Choose an edition to launch:
echo.
echo   [1] Modern Standalone Agent (Go / Charm TUI / Air-Gapped) - Recommended
echo   [2] Legacy PowerShell GUI Configurator (WPF / robocopy.exe)
echo   [3] Exit
echo.
set /p CHOICE="Enter selection (1, 2, or 3) [Default: 1]: "

if "%CHOICE%"=="" set CHOICE=1
if "%CHOICE%"=="1" goto RunGo
if "%CHOICE%"=="2" goto RunLegacy
if "%CHOICE%"=="3" exit /b 0

echo Invalid selection. Launching Modern Go Agent by default...
goto RunGo

:RunGo
if not exist "go\bin\copymaster.exe" (
    echo [INFO] Compiling Go binaries...
    cd go
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\build\Build-Binaries.ps1"
    cd ..
)
start "" "go\bin\copymaster.exe"
exit /b 0

:RunLegacy
cd legacy
call Launch-CopyMaster.bat
exit /b 0

