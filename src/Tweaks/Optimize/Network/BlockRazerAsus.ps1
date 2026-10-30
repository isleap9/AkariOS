# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Block Razer and ASUS Download Servers":
# hosts file lines, kept in Akari's own block (Set-AkariHostsBlock) so Revert removes exactly them.
@{
    Id          = 'network-block-razer-asus'
    Name        = 'Block Razer and ASUS download servers'
    Section     = 'Optimize'
    Category    = 'Network'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Razer Synapse and ASUS Armoury Crate can''t download their apps, updates or ads, or sign in, so their installers (also the ones a new Razer or ASUS device starts) get nowhere. Undo this before using those apps.'
    Detect      = {
        . "$AkariTweakDir\Files\RazerAsusHosts.ps1"
        $have = Get-AkariHostsBlock 'razer-asus'
        if ($null -eq $have) { 'Default' } elseif (($have -join "`n") -eq ((Get-AkariRazerAsusHosts) -join "`n")) { 'Optimized' } else { 'Custom' }
    }
    Apply       = { . "$AkariTweakDir\Files\RazerAsusHosts.ps1"; Set-AkariHostsBlock 'razer-asus' (Get-AkariRazerAsusHosts) }
    Revert      = { Set-AkariHostsBlock 'razer-asus' @() }
}
