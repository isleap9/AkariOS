# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable show me suggested apps in share".
@{
    Id          = 'system-no-share-suggestions'
    Name        = 'No suggested apps in the share window'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'The share window lists only the apps you have, without Store apps suggested to share with.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP'; Name = 'EnablePromotionalAppsForShare'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
