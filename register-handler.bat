@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: Check admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Please run as Administrator
    echo Right-click this file and select "Run as administrator"
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "LAUNCHER=%SCRIPT_DIR%ncm-launcher.ps1"
set "POWERSHELL=powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File"

echo =============================================
echo   NCM File Launcher - INSTALL
echo =============================================
echo.

if not exist "%LAUNCHER%" (
    echo ERROR: ncm-launcher.ps1 not found
    pause
    exit /b 1
)

echo Installing...

:: Step 1: Register our ProgID and command
echo [1/5] Registering launcher ProgID...
reg add "HKCU\Software\Classes\NCMLauncher.ncm" /ve /d "NCM Launcher" /f >nul 2>&1
reg add "HKCU\Software\Classes\NCMLauncher.ncm\Shell\Open\Command" /ve /d "%POWERSHELL% \"%LAUNCHER%\" \"%%1\"" /f >nul 2>&1

:: Step 2: Set .ncm default to our ProgID
echo [2/5] Setting .ncm default association...
reg add "HKCU\Software\Classes\.ncm" /ve /d "NCMLauncher.ncm" /f >nul 2>&1

:: Step 3: Hijack Applications\cloudmusic.exe (UserChoice points here)
echo [3/5] Hijacking Applications\cloudmusic.exe...
reg add "HKCU\Software\Classes\Applications\cloudmusic.exe" /ve /d "NetEase Cloud Music" /f >nul 2>&1
reg add "HKCU\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command" /ve /d "%POWERSHELL% \"%LAUNCHER%\" \"%%1\"" /f >nul 2>&1

:: Step 4: Add to OpenWithProgids
echo [4/5] Registering OpenWithProgids...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ncm\OpenWithProgids" /v "NCMLauncher.ncm" /t REG_NONE /f >nul 2>&1

:: Step 5: Backup original ProgID
echo [5/5] Backing up original state...
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Classes\.ncm" /ve 2^>nul ^| find /i "REG_"') do set "ORIG=%%b"
if not "!ORIG!"=="" (
    if not "!ORIG!"=="NCMLauncher.ncm" (
        reg add "HKCU\Software\Classes\.ncm" /v "OriginalProgID" /d "!ORIG!" /f >nul 2>&1
    )
)

echo.
echo =============================================
echo   Installation Complete!
echo =============================================
echo.
echo Double-click any .ncm file to play.
echo To uninstall: run uninstall.bat as administrator
echo.
pause
exit /b 0
