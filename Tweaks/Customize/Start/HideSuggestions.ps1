# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'start-hide-suggestions'
    Name        = 'No tips and suggested apps in Start'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Start stops recommending tips, shortcuts and new apps.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_IrisRecommendations'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowRecentList'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
