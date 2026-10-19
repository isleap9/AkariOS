# Remove Store (AppX) apps, one Entry per package (data-list Group, ADR 0002; rows in Appx.psd1).
# Action: a removed app only comes back from the Store, so there is no Revert to the Windows Default.
# The engine (EntryKind AppxRemove, Core\Appx.ps1) removes the package for every user and its provisioned copy.
@{
    Id          = 'appx'
    Kind        = 'Group'
    Name        = 'Remove apps'
    Section     = 'Apps'
    Category    = 'Remove'
    Risk        = 'Caution'
    Description = 'Remove Store apps for every user, and keep them from coming back for new users.'
    EntryKind   = 'AppxRemove'
    Entries     = (Import-PowerShellDataFile "$PSScriptRoot\Appx.psd1").Apps
}
