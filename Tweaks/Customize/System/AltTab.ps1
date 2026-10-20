# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-alt-tab-windows-only'
    Name        = 'Alt+Tab shows windows only'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'No Edge tabs in Alt+Tab.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'MultiTaskingAltTabFilter'; Type = 'DWord'; Value = 3; Default = $null }
    )
}
