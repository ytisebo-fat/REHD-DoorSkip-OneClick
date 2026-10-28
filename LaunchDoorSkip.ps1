# Auto launcher for user's confirmed-working RE HD door-skip v2.1 patch.
# Uses Steam's registered URL handler; does not edit files or use network itself.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
function Fail([string]$message) {
    [void][System.Windows.Forms.MessageBox]::Show($message, 'RE HD - Door Skip Launcher', 'OK', 'Error')
    exit 1
}
try {
    $patchScript = Join-Path $PSScriptRoot 'DoorSkipLive.ps1'
    if (-not (Test-Path -LiteralPath $patchScript)) { Fail 'DoorSkipLive.ps1 is missing. Extract all files from the ZIP into the same folder.' }
    $game = @(Get-Process -Name 'bhd' -ErrorAction SilentlyContinue)
    if ($game.Count -eq 0) {
        Write-Host 'Starting Resident Evil HD Remaster through Steam...'
        Start-Process 'steam://rungameid/304240'
    } else {
        Write-Host 'Resident Evil HD Remaster is already running.'
    }
    Write-Host 'Waiting for the game to load...'
    $deadline = [DateTime]::UtcNow.AddMinutes(3)
    do {
        $game = @(Get-Process -Name 'bhd' -ErrorAction SilentlyContinue)
        if ($game.Count -gt 1) { Fail 'Multiple bhd.exe processes found. Close extra copies and try again.' }
        if ($game.Count -eq 1) { break }
        Start-Sleep -Seconds 1
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($game.Count -ne 1) { Fail 'The game did not start within 3 minutes. Make sure Steam is installed, running and owns Resident Evil HD Remaster.' }
    # Allow the game to finish its initial module setup before reading patch locations.
    Start-Sleep -Seconds 5
    if (-not (Get-Process -Id $game[0].Id -ErrorAction SilentlyContinue)) { Fail 'The game closed before Door Skip could be enabled.' }
    Write-Host 'Applying the verified Door Skip v2.1 patch...'
    & $patchScript
} catch {
    Fail $_.Exception.Message
}
