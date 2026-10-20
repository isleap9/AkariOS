# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings: the section switches of the
# new Start menu (one topic Toggle: they only make sense together). FR33THY also hides the pinned section; AkariOS
# keeps it, so that is HidePinnedSection.ps1.
@{
    Id          = 'start-compact-layout'
    Name        = 'Compact new Start menu'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'The new Start menu in its small size: pins and All apps, no recent or suggested sections. Pair it with New Start menu.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowRecentSection'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowSuggestedFiles'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowAllAppsSection'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'StartMenuSize'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'HideUserInformation'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
