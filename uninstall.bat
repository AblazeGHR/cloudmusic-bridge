@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: Check admin (not strictly required for HKCU changes, but good practice)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Note: Some operations may require admin rights.
    echo Consider right-clicking and selecting "Run as administrator"
    echo.
)

set "SCRIPT_DIR=%~dp0"

echo =============================================
echo   NCM File Launcher - UNINSTALL
echo =============================================
echo.
echo This will restore ALL changes made by the fix:
echo   [a] Restore HKCU\...\Applications\cloudmusic.exe command
echo   [b] Remove HKCU\...\Classes\NCMLauncher.ncm
echo   [c] Restore original .ncm file association
echo.
echo Press any key to continue, or Ctrl+C to cancel...
pause >nul

echo.

:: [a] Restore Applications\cloudmusic.exe\shell\open\command
echo [a] Restoring cloudmusic.exe command...
reg add "HKCU\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command" /ve /d "\"D:\software\CloudMusic\cloudmusic.exe\" \"%%1\"" /f >nul 2>&1
echo     Done.

:: [b] Remove our ProgID
echo [b] Removing NCMLauncher.ncm...
reg delete "HKCU\Software\Classes\NCMLauncher.ncm" /f >nul 2>&1
echo     Done.

:: [c] Restore .ncm association
echo [c] Restoring .ncm file association...

:: Get backed-up original ProgID
set "RESTORE="
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Classes\.ncm" /v "OriginalProgID" 2^>nul ^| find /i "OriginalProgID"') do set "RESTORE=%%b"
if "!RESTORE!"=="" (
    for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Classes\.ncm" /v "NCMLauncher_OriginalProgID" 2^>nul ^| find /i "NCMLauncher"') do set "RESTORE=%%b"
)

if not "!RESTORE!"=="" (
    reg add "HKCU\Software\Classes\.ncm" /ve /d "!RESTORE!" /f >nul 2>&1
    reg delete "HKCU\Software\Classes\.ncm" /v "OriginalProgID" /f >nul 2>&1
    reg delete "HKCU\Software\Classes\.ncm" /v "NCMLauncher_OriginalProgID" /f >nul 2>&1
    echo     Restored to: !RESTORE!
) else (
    reg delete "HKCU\Software\Classes\.ncm" /ve /f >nul 2>&1
    echo     Cleared custom association
)

:: [d] Remove OpenWithProgids reference
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ncm\OpenWithProgids" /v "NCMLauncher.ncm" /f >nul 2>&1
echo [d] Removed OpenWithProgids reference

echo.
echo =============================================
echo   All changes have been reversed.
echo   .ncm files will now use the original
echo   NetEase Cloud Music behavior.
echo =============================================
echo.
echo You can safely delete these files:
echo   ncm-launcher.ps1
echo   DropHelper.exe
echo   DropHelper.cs
echo   register-handler.bat
echo   uninstall.bat
echo.
pause
exit /b 0
