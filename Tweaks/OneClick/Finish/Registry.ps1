# One-click's steptwo.ps1 (isleap9/Akari-OS): imports OneClick\reg.reg, the AkariOS settings file. Most of its values
# have one-file Tweaks (marked AkariOS); this covers the rest (notification blobs, setup intents, a few Control Panel
# values).
# Action: a whole settings file, no single Default.
@{
    Id          = 'oneclick-registry'
    Name        = 'AkariOS registry settings (reg.reg)'
    Section     = 'OneClick'
    Category    = 'Finish'
    Kind        = 'Action'
    Risk        = 'Caution'
    Description = 'Imports AkariOS''s reg.reg; its HKEY_CURRENT_USER keys go to the signed-in user.'
    Apply       = {
        $file = Join-Path $AkariRoot 'OneClick\reg.reg'
        if ((Import-AkariRegText (Get-Content -LiteralPath $file -Raw)) -ne 0) { throw 'reg.exe could not import reg.reg' }
    }
}
