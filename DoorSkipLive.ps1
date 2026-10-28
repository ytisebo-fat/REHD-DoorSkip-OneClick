# RE HD Remaster door skip, 2026/09 build. Source-readable, no network, no persistence.
# Patch values adapted from FluffyQuack/rehd-nodoors (see README).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
function Show-Message([string]$text, [string]$icon='Information') {
    [void][System.Windows.Forms.MessageBox]::Show($text, 'Resident Evil HD - Door Skip', 'OK', $icon)
}
$native = @'
using System;
using System.Runtime.InteropServices;
public static class DoorSkipNative {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
  [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr address, [Out] byte[] buffer, UIntPtr size, out UIntPtr read);
  [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool WriteProcessMemory(IntPtr h, IntPtr address, byte[] buffer, UIntPtr size, out UIntPtr written);
  [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool VirtualProtectEx(IntPtr h, IntPtr address, UIntPtr size, uint newProtect, out uint oldProtect);
  [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] public static extern bool FlushInstructionCache(IntPtr h, IntPtr address, UIntPtr size);
}
'@
$h = [IntPtr]::Zero
try {
    $game = @(Get-Process -Name bhd -ErrorAction SilentlyContinue)
    if ($game.Count -ne 1) { throw 'Start Resident Evil HD Remaster through Steam, reach the main menu, then double-click Enable Door Skip.cmd. Only one copy of the game may be running.' }
    $game = $game[0]
    $path = $game.MainModule.FileName
    if ([IO.Path]::GetFileName($path) -ine 'bhd.exe') { throw 'Unexpected process executable. No changes were made.' }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne '39b840663e4b1a6835c60cbd176e4ee6c21b9197fc2c2dd733f2a7c36a0b429a') { throw 'This game executable is not the version we inspected. No changes were made.' }
    $moduleBase = $game.MainModule.BaseAddress.ToInt64()
    if ($moduleBase -ne 0x400000) { throw ('Unexpected game module base 0x{0:X}. No changes were made.' -f $moduleBase) }
    Add-Type -TypeDefinition $native
    $h = [DoorSkipNative]::OpenProcess(0x438, $false, $game.Id) # VM_OPERATION, VM_READ, VM_WRITE, QUERY_INFORMATION
    if ($h -eq [IntPtr]::Zero) { throw 'Windows did not allow access to the game process. No changes were made. Do not disable antivirus protection.' }
    $patches = @(
        @{ Name='Door loop'; Address=0x47C745; Original='8B 77 48 85 F6'; New='E9 11 02 00 00' },
        @{ Name='Door event'; Address=0x47CA65; Original='C7 46 7C 00 00'; New='E9 7E 00 00 00' },
        @{ Name='Door return'; Address=0x47CC3F; Original='81 7E 78 19 01 00 00 75 07 C7 46 78 03 00 00 00 57'; New='5F C7 86 84 00 00 00 03 00 00 00 5E 5D 5B C2 10 00' },
        @{ Name='Lift transition'; Address=0x668A9A; Original='FB'; New='FA' }
    )
    function Bytes([string]$hex) { return [byte[]]@($hex.Split(' ') | ForEach-Object { [Convert]::ToByte($_,16) }) }
    function Read-Bytes([long]$address, [int]$count) {
        $buf = New-Object byte[] $count
        $got = [UIntPtr]::Zero
        if (-not [DoorSkipNative]::ReadProcessMemory($h,[IntPtr]$address,$buf,[UIntPtr]([uint32]$count),[ref]$got) -or $got.ToUInt64() -ne $count) { throw ('Could not read expected game bytes at 0x{0:X}.' -f $address) }
        return ,$buf
    }
    function Same([byte[]]$a, [byte[]]$b) {
        if ($null -eq $a -or $null -eq $b -or $a.Length -ne $b.Length) { return $false }
        for ($i = 0; $i -lt $a.Length; $i++) { if ($a[$i] -ne $b[$i]) { return $false } }
        return $true
    }
    function Write-Bytes([long]$address,[byte[]]$bytes) {
        $old = [uint32]0
        if (-not [DoorSkipNative]::VirtualProtectEx($h,[IntPtr]$address,[UIntPtr]([uint32]$bytes.Length),0x40,[ref]$old)) { throw ('Could not prepare memory at 0x{0:X}.' -f $address) }
        try {
            $written = [UIntPtr]::Zero
            if (-not [DoorSkipNative]::WriteProcessMemory($h,[IntPtr]$address,$bytes,[UIntPtr]([uint32]$bytes.Length),[ref]$written) -or $written.ToUInt64() -ne $bytes.Length) { throw ('Could not write memory at 0x{0:X}.' -f $address) }
            [void][DoorSkipNative]::FlushInstructionCache($h,[IntPtr]$address,[UIntPtr]([uint32]$bytes.Length))
        } finally {
            $unused = [uint32]0
            [void][DoorSkipNative]::VirtualProtectEx($h,[IntPtr]$address,[UIntPtr]([uint32]$bytes.Length),$old,[ref]$unused)
        }
    }
    $originalCount=0; $patchedCount=0
    foreach ($p in $patches) {
        $p.OriginalBytes = Bytes $p.Original
        $p.NewBytes = Bytes $p.New
        $current = Read-Bytes $p.Address $p.OriginalBytes.Length
        if (Same $current $p.OriginalBytes) { $originalCount++ }
        elseif (Same $current $p.NewBytes) { $patchedCount++ }
        else { throw ('Unexpected instructions at {0} (0x{1:X}). No changes were made.' -f $p.Name,$p.Address) }
    }
    if ($patchedCount -eq $patches.Count) { Show-Message 'Door Skip is already enabled! Play the game normally.'; exit 0 }
    if ($patchedCount -ne 0) { throw 'Game appears partially patched. Close and restart the game before trying again. No changes were made.' }
    $done = New-Object System.Collections.ArrayList
    try {
        foreach ($p in $patches) {
            # Record before writing so a partial write can still be reverted.
            [void]$done.Add($p)
            Write-Bytes $p.Address $p.NewBytes
            if (-not (Same (Read-Bytes $p.Address $p.NewBytes.Length) $p.NewBytes)) { throw ('Could not verify patch at {0}.' -f $p.Name) }
        }
    } catch {
        $problem = $_.Exception.Message
        $rollbackErrors = @()
        for ($i=$done.Count-1; $i -ge 0; $i--) {
            try { Write-Bytes $done[$i].Address $done[$i].OriginalBytes } catch { $rollbackErrors += $_.Exception.Message }
        }
        if ($rollbackErrors.Count) { throw ("Patching failed: $problem`nRollback could not be completed. Close the game immediately and restart before retrying. Details: " + ($rollbackErrors -join '; ')) }
        throw ("Patching failed and original game memory was restored. $problem")
    }
    Show-Message "Door Skip is enabled for this game session!`n`nYou can now play normally. The effect ends when you exit the game. Your game files were not modified."
} catch {
    Show-Message ($_.Exception.Message) 'Error'
    exit 1
} finally {
    if ($h -ne [IntPtr]::Zero) { [void][DoorSkipNative]::CloseHandle($h) }
}
