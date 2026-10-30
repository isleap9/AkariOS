# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'update-no-app-archiving'
    Name        = 'No app archiving'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows doesn''t archive apps you rarely use.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx'; Name = 'AllowAutomaticAppArchiving'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
