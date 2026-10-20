# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'power-hide-lock-sleep'
    Name        = 'No Lock and Sleep in the power menu'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The power menu shows only shut down and restart.'
    Registry    = @(
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name = 'ShowLockOption'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'; Name = 'ShowSleepOption'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
