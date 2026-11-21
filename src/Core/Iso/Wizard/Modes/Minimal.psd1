# ISO Builder mode (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes, batch I6): Tiny11 Builder's Tiny11 Core
# mode (ADR 0010: its CleanupCatalog.ForMode(Tiny11Core), Core's registry and its component store pruning), for test
# VMs only. Minimal = $true: an agreement dialog before it can be picked. Irreversible: no updates, features,
# languages or recovery afterwards.
@{
    Name        = 'Minimal'
    Description = 'Tiny11 Core: the smallest image, for test VMs only. No Windows Update, Defender or recovery, and it can never be updated or repaired.'
    Tag         = 'For test VMs only'
    Order       = 3
    Groups      = @('SkipHardwareChecks', 'Tiny11Settings', 'Tiny11Apps', 'EdgeWebView', 'OneDrive', 'Tiny11Features', 'ReservedStorage', 'AutoBitLocker', 'Tiny11Core')
    AkariOS     = $false
    Minimal     = $true
    Settings    = @{ Compression = 'Recovery' }
}
