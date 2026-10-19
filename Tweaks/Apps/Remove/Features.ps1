# Windows features (Control Panel > Turn Windows features on or off) to turn off: one Entry per feature turned on,
# read by the GUI (data-list Group, ADR 0002). FR33THY Ultimate "bloatware" turns off every one except KeepNames.
# Features.psd1 only names and rates the common ones.
# Action: a feature turned off comes back from Turn Windows features on or off, not through an Akari Revert.
@{
    Id          = 'feature'
    Kind        = 'Group'
    Name        = 'Windows features'
    Section     = 'Apps'
    Category    = 'Remove'
    Risk        = 'Caution'
    Description = 'Windows features: Print to PDF, Work Folders, PowerShell 2.0, SMB Direct, Media Features and the rest.'
    EntryKind   = 'FeatureDisable'
    # FR33THY's keep-list: DirectPlay and legacy components (old games), .NET, Search, Defender, and what Windows
    # Server needs for its desktop, internet and the NVIDIA App
    KeepNames   = '*DirectPlay*', '*LegacyComponents*', '*NetFx3*', '*NetFx4*', '*SearchEngine-Client-Package*', '*Server-Shell*',
                  '*Windows-Defender*', '*Server-Drivers-General*', '*ServerCore-Drivers-General*', '*Server-Gui-Mgmt*', '*WirelessNetworking*'
    Entries     = (Import-PowerShellDataFile "$PSScriptRoot\Features.psd1").Rows
}
