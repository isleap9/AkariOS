# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'start-hide-most-used'
    Name        = 'Hide most used apps in Start'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Start no longer lists the apps you open most.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'ShowOrHideMostUsedApps'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowFrequentList'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
