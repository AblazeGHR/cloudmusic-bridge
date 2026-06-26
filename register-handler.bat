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
echo [1/6] Registering launcher ProgID...
reg add "HKCU\Software\Classes\NCMLauncher.ncm" /ve /d "NCM Launcher" /f >nul 2>&1
reg add "HKCU\Software\Classes\NCMLauncher.ncm\Shell\Open\Command" /ve /d "%POWERSHELL% \"%LAUNCHER%\" \"%%1\"" /f >nul 2>&1

:: Step 2: Set .ncm default to our ProgID
echo [2/6] Setting .ncm default association...
reg add "HKCU\Software\Classes\.ncm" /ve /d "NCMLauncher.ncm" /f >nul 2>&1

:: Step 3: Hijack Applications\cloudmusic.exe (UserChoice points here)
echo [3/6] Hijacking Applications\cloudmusic.exe...
reg add "HKCU\Software\Classes\Applications\cloudmusic.exe" /ve /d "NetEase Cloud Music" /f >nul 2>&1
reg add "HKCU\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command" /ve /d "%POWERSHELL% \"%LAUNCHER%\" \"%%1\"" /f >nul 2>&1

:: Step 4: Add to OpenWithProgids
echo [4/6] Registering OpenWithProgids...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ncm\OpenWithProgids" /v "NCMLauncher.ncm" /t REG_NONE /f >nul 2>&1

:: Step 5: Auto-repair on startup (fixed hijack being overwritten by cloudmusic)
echo [5/6] Setting up auto-repair...
copy /Y "%SCRIPT_DIR%startup-repair.bat" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\NCM-Hijack-Repair.bat" >nul 2>&1

:: Step 6: Backup original ProgID
echo [6/6] Backing up original state...
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
echo .ncm files will now open with NetEase Cloud Music.
echo.
echo Auto-repair: runs at startup to re-apply if
echo cloudmusic overwrites the association.
echo.
pause
exit /b 0
