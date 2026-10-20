# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-no-wpbt'
    Name        = 'No software from the firmware'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Windows doesn''t run programs the motherboard firmware asks it to install (WPBT, used by some vendors'' utilities).'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Name = 'DisableWpbtExecution'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
