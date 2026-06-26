# Auto-repair script: runs at Windows logon, checks and fixes the hijack
# Place shortcut in: shell:startup

$logFile = "$env:TEMP\ncm-launcher-repair.log"
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$targetCommand = 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\project\netEasycloudOpener\ncm-launcher.ps1" "%1"'
$regPath = "HKCU:\Software\Classes\Applications\cloudmusic.exe\Shell\Open\Command"

try {
    $current = (Get-ItemProperty -Path $regPath -Name "(default)" -ErrorAction Stop).'(default)'
    if ($current -ne $targetCommand) {
        Set-ItemProperty -Path $regPath -Name "(default)" -Value $targetCommand
        "$ts | FIXED: hijack was overwritten, restored" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
} catch {
    "$ts | ERROR: $_" | Out-File -FilePath $logFile -Append -Encoding UTF8
}
