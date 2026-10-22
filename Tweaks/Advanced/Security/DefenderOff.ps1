# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\1 Defender, the part no other Tweak owns: real-time
# protection, the Defender services and drivers, its right-click entry, the tray icon, and smartscreen.exe moved out of
# System32. Its Windows Security values are security-defender-settings', its SmartScreen and task part
# security-defender-tasks-off's; the Default Definitions feature is feature/Windows-Defender-Default-Definitions
# (FR33THY disables it here, but it can't be turned back on). Defender guards its keys: Safe Mode, TrustedInstaller.
@{
    Id          = 'security-defender-off'
    Name        = 'Microsoft Defender off completely'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    SafeMode    = $true
    Reboot      = $true
    Description = 'Real-time protection, the Defender services and drivers, SmartScreen, its right-click entry and the Windows Security tray icon off: no antivirus at all. Pair it with "Windows Security: protections and notifications off". Needs Safe Mode: Akari restarts into it and back.'
    Confirm     = 'This turns Microsoft Defender off completely: the PC has no antivirus until you revert it or install another one. Select it anyway?'
    Detect      = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\defender-off.psd1").Registry |
            Where-Object { $_.Path -notmatch '\\Services\\' -or (Test-Path -LiteralPath (Resolve-AkariRegPath $_.Path)) })
        $s = Get-AkariRegistryState $rows
        $inSystem32 = Test-Path -LiteralPath "$env:SystemRoot\System32\smartscreen.exe"
        $moved = Test-Path -LiteralPath "$env:SystemRoot\smartscreen.exe"
        if ($s -eq 'Unknown') { 'Unknown' }
        elseif ($s -eq 'Optimized' -and -not $inSystem32) { 'Optimized' }
        elseif ($s -eq 'Default' -and -not $moved) { 'Default' }
        else { 'Custom' }
    }
    Apply       = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\defender-off.psd1").Registry |
            Where-Object { $_.Path -notmatch '\\Services\\' -or (Test-Path -LiteralPath (Resolve-AkariRegPath $_.Path)) })
        # the keys Defender guards as TrustedInstaller, then every row as admin; a value Windows still guards is only logged
        Invoke-AkariRegistryTrusted @($rows | Where-Object { $_.Path -match '\\Services\\|\\Windows Defender\\' }) Apply
        foreach ($r in $rows) { try { Invoke-AkariRegistry @($r) Apply } catch { "Kept by Windows: $($r.Path) $($r.Name) ($($_.Exception.Message))" } }
        Stop-Process -Name smartscreen -Force -ErrorAction SilentlyContinue
        $exe = "$env:SystemRoot\System32\smartscreen.exe"
        if (Test-Path -LiteralPath $exe) { Run-Trusted "cmd /c move /y `"$exe`" `"$env:SystemRoot\smartscreen.exe`"" }
    }
    Revert      = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\defender-off.psd1").Registry |
            Where-Object { $_.Path -notmatch '\\Services\\' -or (Test-Path -LiteralPath (Resolve-AkariRegPath $_.Path)) })
        Invoke-AkariRegistryTrusted @($rows | Where-Object { $_.Path -match '\\Services\\|\\Windows Defender\\' }) Revert
        foreach ($r in $rows) { try { Invoke-AkariRegistry @($r) Revert } catch { "Kept by Windows: $($r.Path) $($r.Name) ($($_.Exception.Message))" } }
        Stop-Process -Name smartscreen -Force -ErrorAction SilentlyContinue
        $exe = "$env:SystemRoot\smartscreen.exe"
        if (Test-Path -LiteralPath $exe) { Run-Trusted "cmd /c move /y `"$exe`" `"$env:SystemRoot\System32\smartscreen.exe`"" }
    }
}
