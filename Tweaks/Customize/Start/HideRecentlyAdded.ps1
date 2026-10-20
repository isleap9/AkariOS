# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'start-hide-recently-added'
    Name        = 'Hide recently added apps in Start'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Start no longer lists apps you just installed.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'HideRecentlyAddedApps'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'HideRecentlyAddedApps'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
