# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-100-percent-scaling'
    Name        = '100% display scaling'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Caution'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Text and apps at 100% (96 DPI) on every screen. Things look small on high-DPI screens.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'LogPixels'; Type = 'DWord'; Value = 96; Default = $null }
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'Win8DpiScaling'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\DWM'; Name = 'UseDpiScaling'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'EnablePerProcessSystemDPI'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
