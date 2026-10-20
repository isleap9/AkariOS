# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'network-no-ics-control'
    Name        = 'Others can''t control a shared connection'
    Section     = 'Optimize'
    Category    = 'Network'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Other network users can''t turn off or change an Internet connection you share.'
    Registry    = @(
        @{ Path = 'HKLM:\System\ControlSet001\Control\Network\SharedAccessConnection'; Name = 'EnableControl'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
