# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\19 Gamebar and 22 Control Panel Settings (One-click does
# the same). The key belongs to TrustedInstaller, so the value is written through Run-Trusted.
@{
    Id          = 'gaming-presence-writer-off'
    Name        = 'Game Bar presence writer off'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'GameBarPresenceWriter.exe no longer starts with every game to tell Xbox what you play.'
    Detect      = {
        $v = Get-AkariRegValue 'HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter' 'ActivationType'
        if ($v -eq 0) { 'Optimized' } elseif ($v -eq 1) { 'Default' } elseif ($null -eq $v) { 'Unknown' } else { 'Custom' }
    }
    Apply       = { Run-Trusted 'reg add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v "ActivationType" /t REG_DWORD /d 0 /f' }
    Revert      = { Run-Trusted 'reg add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v "ActivationType" /t REG_DWORD /d 1 /f' }
}
