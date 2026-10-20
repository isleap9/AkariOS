# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-settings-hide-home'
    Name        = 'No Home page in Settings'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Description = 'Settings opens on System instead of the Home page with its suggestions.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'SettingsPageVisibility'; Type = 'String'; Value = 'hide:home;'; Default = $null }
    )
}
