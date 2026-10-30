# Store apps the debloat (Apps > Remove) can remove, downloaded again from the Microsoft Store through winget: one
# Entry per row of StoreApps.psd1 (data-list Group, ADR 0002). The GUI lists only the ones missing from this PC.
# Action: an app installed again is removed again from the Remove tab, not through an Akari Revert.
@{
    Id          = 'store'
    Kind        = 'Group'
    Name        = 'Restore removed apps'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Restore removed apps'
    Risk        = 'Safe'
    Description = 'Store apps the debloat removed, downloaded again from the Microsoft Store.'
    EntryKind   = 'StoreInstall'
    Entries     = (Import-PowerShellDataFile "$PSScriptRoot\StoreApps.psd1").Rows
}
