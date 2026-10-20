# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'power-video-on-battery'
    Name        = 'Full video quality on battery'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Laptop'
    Description = 'Videos play at full quality on battery too.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\VideoSettings'; Name = 'VideoQualityOnBattery'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
