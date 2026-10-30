# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'performance-background-apps-off'
    Name        = 'Background apps off'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Store apps don''t run in the background (they still notify when open); the Widgets board and touch keyboard don''t preload.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsRunInBackground'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'BackgroundAppGlobalToggle'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name = 'GlobalUserDisabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\input'; Name = 'IsInputAppPreloadEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Dsh'; Name = 'IsPrelaunchEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
