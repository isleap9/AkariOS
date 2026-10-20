# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\29 Power Plan (One-click does the same).
@{
    Id          = 'power-throttling-off'
    Name        = 'Power throttling off'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Windows doesn''t slow down background programs to save power.'
    Registry    = @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'; Name = 'PowerThrottlingOff'; Type = 'DWord'; Value = 1; Default = $null }
}
