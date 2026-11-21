# ISO Builder mode (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): a smaller, update-safe Windows with no
# AkariOS. Groups = removal groups (Wizard/Groups/<Id>.psd1). Settings = the build settings it starts with.
@{
    Name        = 'Lite'
    Description = 'A smaller Windows that keeps updating: safe Store apps, Edge, OneDrive and Windows AI out, no reserved storage or automatic encryption.'
    Tag         = 'Update-safe'
    Order       = 2
    Groups      = @('SkipHardwareChecks', 'NoSponsoredApps', 'StoreAppsSafe', 'Edge', 'OneDrive', 'WindowsAI', 'ReservedStorage', 'AutoBitLocker')
    AkariOS     = $false
    Settings    = @{ Compression = 'Maximum' }
}
