# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable publish to web".
@{
    Id          = 'privacy-no-publishing-wizard'
    Name        = 'No "publish to the web" in Explorer'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Removes the old wizards that upload files and photos to online services from Explorer.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoPublishingWizard'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
