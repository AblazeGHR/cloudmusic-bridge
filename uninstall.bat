@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -Raw '%~f0'; $s=$c.IndexOf('##PS'); Invoke-Expression ($c.Substring($s+5))"
goto :EOF
##PS
# ============================================================
# netEasycloudOpener - Uninstaller
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "netEasycloudOpener Uninstaller"

Write-Host "============================================"
Write-Host "  netEasycloudOpener - Uninstaller"
Write-Host "============================================"
Write-Host ""

# ---- Restore Applications\cloudmusic.exe ----
Write-Host "[1/4] Restoring original cloudmusic.exe command..."

# Find cloudmusic.exe from running process or common paths
$cloudExe = $null
$proc = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
if ($proc) { $cloudExe = $proc.Path }

if (-not $cloudExe) {
    $search = @(
        "$env:LOCALAPPDATA\NetEase\CloudMusic\cloudmusic.exe",
        "${env:ProgramFiles(x86)}\Netease\CloudMusic\cloudmusic.exe",
        "$env:ProgramFiles\Netease\CloudMusic\cloudmusic.exe"
    )
    foreach ($p in $search) {
        if (Test-Path $p) { $cloudExe = $p; break }
    }
}

if ($cloudExe) {
    $origCmd = "`"$cloudExe`" `"%1`""
    Set-ItemProperty "HKCU:\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command" -Name "(default)" -Value $origCmd
    Write-Host "  Restored to: $origCmd"
} else {
    # Just remove our custom entry
    Remove-Item "HKCU:\Software\Classes\Applications\cloudmusic.exe" -Recurse -Force
    Write-Host "  Removed custom entry (cloudmusic not found to restore)"
}

# ---- Remove NCMLauncher.ncm ----
Write-Host "[2/4] Removing launcher ProgID..."
Remove-Item "HKCU:\Software\Classes\NCMLauncher.ncm" -Recurse -Force
Write-Host "  Removed"

# ---- Restore .ncm default ----
Write-Host "[3/4] Restoring .ncm file association..."
# Try to restore from backup
$backup = (Get-ItemProperty "HKCU:\Software\Classes\.ncm" -Name "OriginalProgID" -ErrorAction SilentlyContinue).OriginalProgID
if ($backup) {
    Set-ItemProperty "HKCU:\Software\Classes\.ncm" -Name "(default)" -Value $backup
    Remove-ItemProperty "HKCU:\Software\Classes\.ncm" -Name "OriginalProgID"
    Write-Host "  Restored to: $backup"
} else {
    Remove-ItemProperty "HKCU:\Software\Classes\.ncm" -Name "(default)"
    Write-Host "  Cleared custom association"
}

# ---- Remove OpenWithProgids ref ----
Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ncm\OpenWithProgids" -Name "NCMLauncher.ncm"
Write-Host "  Cleaned OpenWithProgids"

# ---- Remove startup repair ----
Write-Host "[4/4] Removing startup auto-repair..."
$startupDir = [Environment]::GetFolderPath("Startup")
$startupFile = Join-Path $startupDir "NCM-Hijack-Repair.bat"
if (Test-Path $startupFile) {
    Remove-Item $startupFile -Force
    Write-Host "  Removed: $startupFile"
} else {
    Write-Host "  Not found (already removed)"
}

Write-Host ""
Write-Host "============================================"
Write-Host "  Uninstall Complete"
Write-Host "============================================"
Write-Host ""
Write-Host "  Registry restored to original state."
Write-Host "  .ncm files will use default Windows behavior."
Write-Host ""
Write-Host "  You may now delete the install directory if"
Write-Host "  you no longer need the files."
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
