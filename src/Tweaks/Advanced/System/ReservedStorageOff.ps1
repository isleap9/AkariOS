# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksReservedStorage".
@{
    Id          = 'system-reserved-storage-off'
    Name        = 'Reserved storage off'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Caution'
    Guided      = $false
    Reboot      = $true
    Description = 'Gives back the space (around 7 GB) Windows keeps for updates. With a nearly full drive, updates may then fail. DISM refuses while an update is in progress.'
    Detect      = {
        switch (Get-AkariReservedStorage) { 'Disabled' { 'Optimized' } 'Enabled' { 'Default' } default { 'Unknown' } }
    }
    Apply       = {
        $c = Invoke-AkariDism /Online /Set-ReservedStorageState /State:Disabled
        if ($c -ne 0) { throw ('DISM could not change reserved storage (0x{0:X8}): let Windows Update finish, restart, then try again.' -f $c) }
    }
    Revert      = {
        $c = Invoke-AkariDism /Online /Set-ReservedStorageState /State:Enabled
        if ($c -ne 0) { throw ('DISM could not change reserved storage (0x{0:X8}): let Windows Update finish, restart, then try again.' -f $c) }
    }
}
