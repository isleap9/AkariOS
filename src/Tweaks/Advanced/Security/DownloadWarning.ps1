# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\5 File Download Security Warning.
@{
    Id          = 'security-download-warning-off'
    Name        = 'No security warning on downloaded files'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Caution'
    Description = 'Files from the internet open without the "Open File - Security Warning" prompt.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Security'; Name = 'DisableSecuritySettingsCheck'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3'; Name = '1806'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3'; Name = '1806'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
