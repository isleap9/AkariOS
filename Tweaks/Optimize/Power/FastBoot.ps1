# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\29 Power Plan (One-click does the same).
@{
    Id          = 'power-fast-startup-off'
    Name        = 'Fast startup off'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Shut down really shuts down: drivers and Windows start fresh every time.'
    Registry    = @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Type = 'DWord'; Value = 0; Default = 1 }
}
