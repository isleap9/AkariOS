# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json
# "WPFFeatureEnableLegacyRecovery" / "WPFFeatureDisableLegacyRecovery": one Toggle. A boot setting (bcdedit): Detect
# reads the current boot entry (bcdedit prints Legacy / Standard in English on every language).
@{
    Id          = 'features-f8-recovery'
    Name        = 'Legacy F8 boot recovery'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Safe'
    Guided      = $false
    Reboot      = $true
    Description = 'Pressing F8 while Windows starts opens the Advanced Boot Options screen (Safe Mode, last known good settings), as on Windows 7. Starting up waits a moment longer for the key.'
    Detect      = {
        $p = @(Read-AkariBcd | ForEach-Object { if ($_ -match '^bootmenupolicy\s+(\S+)') { $Matches[1] } })
        if ($p.Count -and $p[0] -eq 'Legacy') { 'Optimized' } else { 'Default' }
    }
    Apply       = { if ((Invoke-AkariBcdEdit '/set {current} bootmenupolicy legacy') -ne 0) { throw 'bcdedit could not change the boot menu' } }
    Revert      = { if ((Invoke-AkariBcdEdit '/set {current} bootmenupolicy standard') -ne 0) { throw 'bcdedit could not change the boot menu' } }
}
