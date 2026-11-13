# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleNewOutlook"
# (the other way round: AkariOS keeps classic Outlook).
@{
    Id          = 'apps-classic-outlook'
    Name        = 'Outlook: stay on classic'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Classic Outlook (Microsoft 365, Office 2016 and later) stays: no "Try the new Outlook" switch and no automatic move to the new one.'
    Registry    = @(
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Office\16.0\Outlook\Preferences'; Name = 'UseNewOutlook'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General'; Name = 'HideNewOutlookToggle'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Options\General'; Name = 'DoNewOutlookAutoMigration'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Office\16.0\Outlook\Preferences'; Name = 'NewOutlookMigrationUserSetting'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
