# ISO Builder mode (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): Tiny11 Builder's Tiny11 mode (ADR 0010:
# its CleanupCatalog.ForMode(Tiny11) and its default Recovery ESD), a smaller Windows that still updates. No AkariOS.
# Groups = removal groups (Wizard/Groups/<Id>.psd1). Settings = the build settings it starts with.
@{
    Name        = 'Lite'
    Description = 'Tiny11''s set: the bundled apps, Edge and WebView2, OneDrive, ads and Copilot out; Windows Update, Defender, recovery and the Store kept.'
    Tag         = 'Update-safe'
    Order       = 2
    Groups      = @('SkipHardwareChecks', 'Tiny11Settings', 'Tiny11Apps', 'Tiny11AppsExtra', 'EdgeWebView', 'OneDrive', 'Tiny11Features', 'ReservedStorage', 'AutoBitLocker')
    AkariOS     = $false
    Settings    = @{ Compression = 'Recovery' }
}
