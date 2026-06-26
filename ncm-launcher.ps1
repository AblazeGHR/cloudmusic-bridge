# NCM File Launcher v6 - WM_DROPFILES with optimized waits
param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

$logFile = "$env:TEMP\ncm-launcher.log"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    try { "$ts | $msg" | Out-File -FilePath $logFile -Append -Encoding UTF8 } catch {}
}

Write-Log "=== START v5 ==="
Write-Log "Raw arg: $FilePath"

# Resolve file path
try {
    $FilePath = (Resolve-Path -Path $FilePath -ErrorAction Stop).Path
    Write-Log "Resolved path: $FilePath"
} catch {
    Write-Log "ERROR: Cannot resolve path: $_"
    exit 1
}

# Locate DropHelper.exe
$dropHelper = Join-Path $scriptDir "DropHelper.exe"
Write-Log "DropHelper path: $dropHelper"
if (-not (Test-Path $dropHelper)) {
    Write-Log "ERROR: DropHelper.exe not found"
    exit 1
}

# Find cloudmusic.exe
$searchPaths = @(
    "$env:LOCALAPPDATA\NetEase\CloudMusic\cloudmusic.exe",
    "${env:ProgramFiles(x86)}\Netease\CloudMusic\cloudmusic.exe",
    "$env:ProgramFiles\Netease\CloudMusic\cloudmusic.exe",
    "D:\software\CloudMusic\cloudmusic.exe",
    "D:\Program Files\Netease\CloudMusic\cloudmusic.exe"
)

$cloudMusicExe = $null
foreach ($p in $searchPaths) {
    if (Test-Path $p) {
        $cloudMusicExe = $p
        break
    }
}

if (-not $cloudMusicExe) {
    $proc = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path) { $cloudMusicExe = $proc.Path }
}

Write-Log "cloudmusic.exe: $cloudMusicExe"
if (-not $cloudMusicExe) {
    Write-Log "ERROR: cloudmusic.exe not found"
    exit 1
}

# Ensure cloudmusic is running
$isRunningBefore = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue
Write-Log "CloudMusic already running: $($isRunningBefore -ne $null)"

if (-not $isRunningBefore) {
    Write-Log "Starting cloudmusic..."
    $proc = Start-Process -FilePath $cloudMusicExe -PassThru
    Write-Log "Started PID=$($proc.Id)"
}

# Wait for a window to appear (with MainWindowHandle != 0)
$windowFound = $false
$maxWait = 200  # 20 seconds
$waited = 0
while ($waited -lt $maxWait) {
    $running = Get-Process -Name "cloudmusic" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1
    if ($running) {
        $windowFound = $true
        Write-Log "Window found after ${waited}00ms: PID=$($running.Id) HWND=$($running.MainWindowHandle)"
        break
    }
    Start-Sleep -Milliseconds 100
    $waited++
}

if (-not $windowFound) {
    Write-Log "ERROR: Window not found after 20s. Trying DropHelper anyway..."
}

# Wait for window readiness
# WM_DROPFILES uses PostMessage (async), so the message will be queued
# and processed when the window loop is ready — we only need minimal delay.
if (-not $isRunningBefore) {
    # Cold start: gave extra time for UI/drop-target init
    Write-Log "Cold start, waiting 1.5s for full init..."
    Start-Sleep -Seconds 1.5
} else {
    # Warm start: window already processing messages, minimal delay
    Start-Sleep -Milliseconds 200
}
Write-Log "Ready to call DropHelper..."

# Call DropHelper with retries (up to 3 attempts)
$success = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
    Write-Log "DropHelper attempt $attempt/3: $dropHelper `"$FilePath`""
    try {
        $output = & $dropHelper $FilePath 2>&1
        Write-Log "DropHelper output: $output"
        $success = $true
        break
    } catch {
        Write-Log "DropHelper error: $_"
    }
    Start-Sleep -Seconds 2
}

if ($success) {
    Write-Log "=== SUCCESS ==="
} else {
    Write-Log "=== FAILED after 3 attempts ==="
}
