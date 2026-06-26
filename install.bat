@echo off
setlocal
for /f "delims=:" %%n in ('findstr /n /b "##PS" "%~f0"') do set SKIP=%%n
set /a SKIP+=0
set "NCM_INSTALL_DIR=%~dp0"
powershell -NoProfile -Command "(Get-Content '%~f0' | Select-Object -Skip %SKIP%) | Set-Content -Path '%TEMP%\ncm_install.ps1' -Encoding UTF8"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\ncm_install.ps1"
set ERR=%ERRORLEVEL%
del "%TEMP%\ncm_install.ps1" 2>nul
exit /b %ERR%
##PS
# ============================================================
# netEasycloudOpener - Installer
# ============================================================

$ErrorActionPreference = "Stop"
[Console]::Title = "netEasycloudOpener Installer"

$installDir = $env:NCM_INSTALL_DIR
if (-not $installDir) { $installDir = Split-Path -Parent ((Get-Command $MyInvocation.MyCommand.Path).Path) }
if (-not $installDir) { $installDir = (Get-Location).Path }
$installDir = $installDir.TrimEnd('\')

Write-Host "============================================"
Write-Host "  netEasycloudOpener - Installer"
Write-Host "============================================"
Write-Host ""

# ---- Step 1: Find cloudmusic.exe ----
Write-Host "[1/5] Detecting NetEase Cloud Music..."

$cloudExe = $null

# Method 1: extract from existing Windows association
try {
    $regPaths = @(
        "HKCU:\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command",
        "Registry::HKEY_CLASSES_ROOT\Applications\cloudmusic.exe\Shell\Open\Command"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            $existing = (Get-ItemProperty $rp -ErrorAction SilentlyContinue).'(default)'
            if ($existing -and ($existing -ne '')) {
                $clean = $existing -replace '"%1"','' -replace '"','' -replace "`"%1`"",'' -replace '\s+$',''
                $clean = $clean.Trim('"').Trim()
                if (Test-Path $clean) { $cloudExe = $clean; break }
            }
        }
    }
} catch {}

# Method 2: search common paths
if (-not $cloudExe) {
    $search = @(
        "$env:LOCALAPPDATA\NetEase\CloudMusic\cloudmusic.exe",
        "${env:ProgramFiles(x86)}\Netease\CloudMusic\cloudmusic.exe",
        "$env:ProgramFiles\Netease\CloudMusic\cloudmusic.exe"
    )
    foreach ($p in $search) { if (Test-Path $p) { $cloudExe = $p; break } }
}

# Method 3: from running process
if (-not $cloudExe) {
    $proc = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
    if ($proc) { $cloudExe = $proc.Path }
}

# Method 4: ask user with file picker
if (-not $cloudExe) {
    Write-Host "  Could not auto-detect cloudmusic.exe"
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select cloudmusic.exe"
    $dialog.Filter = "cloudmusic.exe|cloudmusic.exe"
    $dialog.InitialDirectory = [Environment]::GetFolderPath('ProgramFiles')
    if ($dialog.ShowDialog() -eq 'OK') {
        $cloudExe = $dialog.FileName
    } else {
        Write-Host "  ERROR: No cloudmusic.exe selected. Aborting."
        Pause
        exit 1
    }
}

Write-Host "  Found: $cloudExe"
Write-Host ""

# ---- Step 2: Generate files ----
Write-Host "[2/5] Generating files..."

# 2a: DropHelper.exe from base64
$dhB64 = "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lwP+AKEAngQFAQkAeAFkAAkABAANAAkACAASAAkADAAXAC4AEwAsAS4AGwA1AcEAKwCYACACKwCYALEACQEVAyADAAEDAIYAAQBAAQUAkQABAEABBwCeAAEAQAEJALcAAQAAAQsA3QABAAABDQDqAAEAQAEPAPgAAQBAAREABAEBAAABEwAQAQIAAAEVABwBAgAAARcAJwECAAABGQA0AQIAAAEdAF4BAQAEgAAAAAAAAAAAAAAAAAAAAAAZAAAABAAAAAAAAAAAAAAAAQA0AAAAAAAEAAAAAAAAAAAAAAABAD0AAAAAAAMAAgAAAAAAADxNb2R1bGU+AERyb3BIZWxwZXIuZXhlAERyb3BIZWxwZXIARW51bVdpbmRvd3NQcm9jAG1zY29ybGliAFN5c3RlbQBPYmplY3QATXVsdGljYXN0RGVsZWdhdGUAR01FTV9NT1ZFQUJMRQBHTUVNX1pFUk9JTklUAFdNX0RST1BGSUxFUwBGaW5kV2luZG93AEZpbmRXaW5kb3dFeABHZXRXaW5kb3dUaHJlYWRQcm9jZXNzSWQARW51bVdpbmRvd3MAU3lzdGVtLlRleHQAU3RyaW5nQnVpbGRlcgBHZXRDbGFzc05hbWUAR2V0V2luZG93VGV4dABQb3N0TWVzc2FnZQBTZW5kTWVzc2FnZQBHbG9iYWxBbGxvYwBHbG9iYWxMb2NrAEdsb2JhbFVubG9jawBHbG9iYWxGcmVlAGZvdW5kSHduZAB0YXJnZXRQcm9jZXNzSWQATWFpbgBJc1dpbmRvd1Zpc2libGUASXNWaXNpYmxlAC5jdG9yAEludm9rZQBJQXN5bmNSZXN1bHQAQXN5bmNDYWxsYmFjawBCZWdpbkludm9rZQBFbmRJbnZva2UAbHBDbGFzc05hbWUAbHBXaW5kb3dOYW1lAGh3bmRQYXJlbnQAaHduZENoaWxkQWZ0ZXIAbHBzekNsYXNzAGxwc3pXaW5kb3cAaFduZABscGR3UHJvY2Vzc0lkAFN5c3RlbS5SdW50aW1lLkludGVyb3BTZXJ2aWNlcwBPdXRBdHRyaWJ1dGUAbHBFbnVtRnVuYwBsUGFyYW0Abk1heENvdW50AGxwU3RyaW5nAE1zZwB3UGFyYW0AdUZsYWdzAGR3Qnl0ZXMAaE1lbQBhcmdzAG9iamVjdABtZXRob2QAY2FsbGJhY2sAcmVzdWx0AFN5c3RlbS5SdW50aW1lLkNvbXBpbGVyU2VydmljZXMAQ29tcGlsYXRpb25SZWxheGF0aW9uc0F0dHJpYnV0ZQBSdW50aW1lQ29tcGF0aWJpbGl0eUF0dHJpYnV0ZQBEbGxJbXBvcnRBdHRyaWJ1dGUAdXNlcjMyLmRsbABrZXJuZWwzMi5kbGwAPE1haW4+Yl9fMABDUyQ8PjlfX0NhY2hlZEFub255bW91c01ldGhvZERlbGVnYXRlMQBDb21waWxlckdlbmVyYXRlZEF0dHJpYnV0ZQBUb1N0cmluZwBDbGVhcgBJbnRQdHIAU3RyaW5nAENvbmNhdABDb25zb2xlAFdyaXRlTGluZQBaZXJvAG9wX0VxdWFsaXR5AFN5c3RlbS5JTwBUZXh0V3JpdGVyAGdldF9FcnJvcgBFbnZpcm9ubWVudABFeGl0AFN5c3RlbS5EaWFnbm9zdGljcwBQcm9jZXNzAEdldFByb2Nlc3Nlc0J5TmFtZQBnZXRfTWFpbldpbmRvd0hhbmRsZQBvcF9JbmVxdWFsaXR5AGdldF9JZABJbnQzMgBFbmNvZGluZwBnZXRfVW5pY29kZQBHZXRCeXRlcwBVSW50UHRyAG9wX0V4cGxpY2l0AE1hcnNoYWwAV3JpdGVJbnQzMgBXcml0ZUJ5dGUAR2V0TGFzdFdpbjMyRXJyb3IALmNjdG9yAAAADyAAIABIAFcATgBEAD0AAA8gAGMAbABhAHMAcwA9AAAPIAB0AGkAdABsAGUAPQAAQVUAcwBhAGcAZQA6ACAARAByAG8AcABIAGUAbABwAGUAcgAuAGUAeABlACAAPABmAGkAbABlAC4AbgBjAG0APgAADUYAaQBsAGUAOgAgAAAVYwBsAG8AdQBkAG0AdQBzAGkAYwAAQUUAUgBSAE8AUgA6ACAAYwBsAG8AdQBkAG0AdQBzAGkAYwAgAGkAcwAgAG4AbwB0ACAAcgB1AG4AbgBpAG4AZwAAJUYAbwB1AG4AZAAgAHcAaQBuAGQAbwB3ADoAIABQAEkARAA9AAANIABIAFcATgBEAD0AAHNNAGEAaQBuAFcAaQBuAGQAbwB3AEgAYQBuAGQAbABlACAAaQBzACAAZQBtAHAAdAB5ACwAIABzAGUAYQByAGMAaABpAG4AZwAgAGYAbwByACAA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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
$dhBytes = [Convert]::FromBase64String($dhB64)
$dhPath = Join-Path $installDir "DropHelper.exe"
[IO.File]::WriteAllBytes($dhPath, $dhBytes)
Write-Host "  DropHelper.exe"

# 2b: ncm-launcher.ps1
$cloudEscaped = $cloudExe -replace '\\','\\'
$launcherContent = @"
# NCM File Launcher v7 - WM_DROPFILES bridge
param(
    [Parameter(Mandatory=`$true)]
    [string]`$FilePath
)

`$logFile = "`$env:TEMP\ncm-launcher.log"
`$scriptDir = Split-Path -Parent `$MyInvocation.MyCommand.Path

function Write-Log(`$msg) {
    `$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    try { "`$ts | `$msg" | Out-File -FilePath `$logFile -Append -Encoding UTF8 } catch {}
}

Write-Log "=== START ==="
Write-Log "Raw arg: `$FilePath"

try { `$FilePath = (Resolve-Path -Path `$FilePath -ErrorAction Stop).Path }
catch { Write-Log "ERROR: Cannot resolve path: `$_"; exit 1 }
Write-Log "Resolved path: `$FilePath"

`$dropHelper = Join-Path `$scriptDir "DropHelper.exe"
if (-not (Test-Path `$dropHelper)) {
    Write-Log "ERROR: DropHelper.exe not found at `$dropHelper"
    exit 1
}

`$cloudMusicExe = "$cloudEscaped"
if (-not (Test-Path `$cloudMusicExe)) {
    `$proc = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue | Where-Object { `$_.Path } | Select-Object -First 1
    if (`$proc) { `$cloudMusicExe = `$proc.Path }
}
Write-Log "cloudmusic.exe: `$cloudMusicExe"

`$isRunningBefore = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue
if (-not `$isRunningBefore) {
    Write-Log "Starting cloudmusic..."
    Start-Process -FilePath `$cloudMusicExe | Out-Null
}

`$windowFound = `$false
for (`$i = 0; `$i -lt 200; `$i++) {
    `$running = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue |
        Where-Object { `$_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (`$running) {
        `$windowFound = `$true
        Write-Log "Window found after `$(`$i*100)ms: PID=`$(`$running.Id)"
        break
    }
    Start-Sleep -Milliseconds 100
}

if (-not `$isRunningBefore) {
    Write-Log "Cold start, waiting 1.5s..."
    Start-Sleep -Seconds 1.5
} else {
    Start-Sleep -Milliseconds 200
}
Write-Log "Ready to call DropHelper..."

for (`$attempt = 1; `$attempt -le 3; `$attempt++) {
    Write-Log "DropHelper attempt `$attempt/3"
    try {
        `$output = & `$dropHelper `$FilePath 2>&1
        Write-Log "DropHelper output: `$output"
        Write-Log "=== SUCCESS ==="
        exit 0
    } catch {
        Write-Log "DropHelper error: `$_"
    }
    Start-Sleep -Seconds 2
}
Write-Log "=== FAILED ==="
exit 1
"@
$launcherPath = Join-Path $installDir "ncm-launcher.ps1"
[IO.File]::WriteAllText($launcherPath, $launcherContent, [Text.Encoding]::UTF8)
Write-Host "  ncm-launcher.ps1"

# 2c: auto-repair.ps1
$repairContent = @"
`$logFile = "`$env:TEMP\ncm-launcher-repair.log"
`$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
`$target = 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "$installDir\ncm-launcher.ps1" "%1"'
`$regPath = "HKCU:\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command"
try {
    `$current = (Get-ItemProperty -Path `$regPath -Name "(default)" -ErrorAction Stop).'(default)'
    if (`$current -ne `$target) {
        Set-ItemProperty -Path `$regPath -Name "(default)" -Value `$target
        "`$ts | FIXED: hijack restored" | Out-File -FilePath `$logFile -Append -Encoding UTF8
    }
} catch {
    "`$ts | ERROR: `$_" | Out-File -FilePath `$logFile -Append -Encoding UTF8
}
"@
$repairPath = Join-Path $installDir "auto-repair.ps1"
[IO.File]::WriteAllText($repairPath, $repairContent, [Text.Encoding]::UTF8)
Write-Host "  auto-repair.ps1"

# 2d: startup-repair.bat
$startupContent = "@echo off`r`npowershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$installDir\auto-repair.ps1`"`r`n"
$startupPath = Join-Path $installDir "startup-repair.bat"
[IO.File]::WriteAllText($startupPath, $startupContent, [Text.Encoding]::ASCII)
Write-Host "  startup-repair.bat"
Write-Host ""

# ---- Step 3: Register file association ----
Write-Host "[3/5] Registering file association..."

$launcherCmd = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`" `"%1`""

New-Item "HKCU:\Software\Classes\NCMLauncher.ncm\Shell\Open\Command" -Force | Out-Null
Set-ItemProperty "HKCU:\Software\Classes\NCMLauncher.ncm\Shell\Open\Command" -Name "(default)" -Value $launcherCmd

Set-ItemProperty "HKCU:\Software\Classes\.ncm" -Name "(default)" -Value "NCMLauncher.ncm" -Force

New-Item "HKCU:\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command" -Force | Out-Null
Set-ItemProperty "HKCU:\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command" -Name "(default)" -Value $launcherCmd

Write-Host "  Registry updated"
Write-Host ""

# ---- Step 4: Set up auto-repair ----
Write-Host "[4/5] Setting up startup auto-repair..."

$startupDir = [Environment]::GetFolderPath("Startup")
$startupDest = Join-Path $startupDir "NCM-Hijack-Repair.bat"
try {
    Copy-Item $startupPath $startupDest -Force
    Write-Host "  Startup repair installed"
} catch {
    Write-Host "  WARNING: Could not copy to Startup folder: $_"
}
Write-Host ""

# ---- Step 5: Verify ----
Write-Host "[5/5] Verifying installation..."
Write-Host ""

if (Test-Path $dhPath) { Write-Host "  [OK] DropHelper.exe" } else { Write-Host "  [FAIL] DropHelper.exe" }
if (Test-Path $launcherPath) { Write-Host "  [OK] ncm-launcher.ps1" } else { Write-Host "  [FAIL] ncm-launcher.ps1" }
if (Test-Path $repairPath) { Write-Host "  [OK] auto-repair.ps1" } else { Write-Host "  [FAIL] auto-repair.ps1" }

$regCmd = (Get-ItemProperty "HKCU:\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command" -ErrorAction SilentlyContinue).'(default)'
if ($regCmd -match 'ncm-launcher') { Write-Host "  [OK] Registry hijack" } else { Write-Host "  [FAIL] Registry hijack" }

Write-Host ""
Write-Host "============================================"
Write-Host "  Installation Complete!"
Write-Host "============================================"
Write-Host ""
Write-Host "  Install dir:  $installDir"
Write-Host "  CloudMusic:   $cloudExe"
Write-Host ""
Write-Host "  You can now double-click any .ncm file."
Write-Host "  If it stops working, auto-repair on startup."
Write-Host ""
Write-Host "  To uninstall: run uninstall.bat"
Write-Host ""
Pause
