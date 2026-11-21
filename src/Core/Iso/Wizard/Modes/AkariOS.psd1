# ISO Builder mode (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes and "AkariOS already applied"): the AkariOS
# setup out of the box. Groups = removal groups (Wizard/Groups/<Id>.psd1). AkariOS = the AkariOS preset baked in: its
# registry-only Tweaks written into the image's hives, AkariOS-Native.exe copied in, and the rest of the preset run
# at the first sign-in. Settings = the build settings it starts with (IsoBuildSettings' names).
@{
    Name        = 'AkariOS'
    Description = 'The AkariOS setup out of the box: One-click''s app removals done in the image, its settings already written, and the rest run at the first sign-in.'
    Tag         = 'Recommended'
    Order       = 1
    Groups      = @('SkipHardwareChecks', 'NoSponsoredApps', 'StoreAppsAkariOS', 'Edge', 'OneDrive')
    AkariOS     = $true
    Settings    = @{ Compression = 'Maximum' }
}
