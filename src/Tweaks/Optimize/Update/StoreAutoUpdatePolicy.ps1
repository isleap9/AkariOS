# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable update apps automatically": the
# policy value (update-store-auto-update sets the Store's own setting).
@{
    Id          = 'update-store-auto-update-policy'
    Name        = 'Block automatic Store app updates by policy'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Group policy turns off automatic app updates in the Microsoft Store and greys out its switch. Apps update when you press Get updates.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; Name = 'AutoDownload'; Type = 'DWord'; Value = 2; Default = $null }
    )
}
