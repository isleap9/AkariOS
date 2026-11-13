# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksDiskCleanup":
# its DISM part (its cleanmgr part is cleanup-disk-cleanup).
# Action: superseded components are deleted for good.
@{
    Id          = 'tools-component-cleanup'
    Name        = 'Component store cleanup'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Caution'
    Description = 'DISM removes the old versions of Windows components that updates replaced (WinSxS), often several GB. It can take a long while.'
    Confirm     = 'Clean up the component store now? Installed updates can''t be uninstalled afterwards, and it may take a long while.'
    Apply       = {
        $c = Invoke-AkariDism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
        if ($c -ne 0 -and $c -ne 3010) { throw ('DISM''s component cleanup failed (0x{0:X8}).' -f $c) }
    }
}
