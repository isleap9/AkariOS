# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json
# "WPFTweaksDisableStoreSearch". winutil denies Everyone full control of the Store's search database; Akari denies its
# data only (read, write, append: mask 7), so the rule itself stays readable and Revert can lift it.
@{
    Id          = 'apps-store-no-search-ads'
    Name        = 'Microsoft Store: no recommended search results'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Start and taskbar search stop showing Microsoft Store app suggestions: the Store''s search database is locked for the real user. Needs the Store opened once first.'
    Detect      = {
        $db = Join-Path (Get-AkariUserFolder 'Local AppData') 'Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db'
        if (-not (Test-Path -LiteralPath $db)) { return 'Unknown' }
        $r = Get-AkariDenyRule $db
        if (($r -band 7) -eq 7) { 'Optimized' } elseif ($r -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $db = Join-Path (Get-AkariUserFolder 'Local AppData') 'Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db'
        if (-not (Test-Path -LiteralPath $db)) { throw 'Open the Microsoft Store once first: it has no search database yet.' }
        Set-AkariDenyRule $db 7
    }
    Revert      = {
        $db = Join-Path (Get-AkariUserFolder 'Local AppData') 'Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db'
        if (Test-Path -LiteralPath $db) { Set-AkariDenyRule $db 0 }
    }
}
