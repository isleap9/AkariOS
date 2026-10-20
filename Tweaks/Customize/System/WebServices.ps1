# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-no-web-services'
    Name        = 'No Internet file associations and publishing wizards'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'File Explorer doesn''t look up unknown file types online or offer web publishing.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoWebServices'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
