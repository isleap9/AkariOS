# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Hide removable drives from navigation
# pane": the delegate folder key is deleted. Revert creates it again (its presence is what counts; the name it held is
# only a label).
@{
    Id          = 'explorer-hide-removable-drives'
    Name        = 'Hide the separate removable drives entries'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'USB sticks and other removable drives show only under This PC, not a second time on their own in the navigation pane.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}'; Value = $null; Default = 'Key' }
    )
}
