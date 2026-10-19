# Optional features (Windows capabilities: Settings > Optional features) to remove: one Entry per capability installed
# on the PC, read by the GUI (data-list Group, ADR 0002). FR33THY Ultimate "bloatware" removes every one except
# KeepNames. Capabilities.psd1 only names and rates the common ones.
# Action: a removed feature comes back from Settings > Optional features, not through an Akari Revert.
@{
    Id          = 'capability'
    Kind        = 'Group'
    Name        = 'Optional features'
    Section     = 'Apps'
    Category    = 'Remove'
    Risk        = 'Caution'
    Description = 'Windows optional features: Steps Recorder, WordPad, Math Recognizer, Internet Explorer mode and the rest.'
    EntryKind   = 'CapabilityRemove'
    # FR33THY's keep-list: network drivers, Windows 10 Paint and Notepad, .NET 3.5, and what installers, monitoring
    # tools and the Snipping Tool need
    KeepNames   = '*Microsoft.Windows.Ethernet*', '*Microsoft.Windows.MSPaint*', '*Microsoft.Windows.Notepad*',
                  '*Microsoft.Windows.Wifi*', '*NetFX3*', '*VBSCRIPT*', '*WMIC*', '*Windows.Client.ShellComponents*'
    Entries     = (Import-PowerShellDataFile "$PSScriptRoot\Capabilities.psd1").Rows
}
