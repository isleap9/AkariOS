# network-block-razer-asus's hosts lines (ZOICWARE's list)
function Get-AkariRazerAsusHosts {
    $hosts = 'synapse3ui-common.razerzone.com', 'bespoke-analytics.razerapi.com', 'discovery.razerapi.com', 'manifest.razerapi.com',
        'cdn.razersynapse.com', 'assets.razerzone.com', 'assets2.razerzone.com', 'deals-assets-cdn.razerzone.com',
        'synapse-3-webservice.razerzone.com', 'albedozero.razerapi.com', 'gms.razersynapse.com', 'fs.razersynapse.com', 'id.razer.com',
        'liveupdate01s.asus.com', 'asusactivateservice.azurewebsites.net', 'rog-live-service.asus.com', 'dlcdn-rogboxbu1.asus.com',
        'dlcdn-rogboxbu2.asus.com', 'mymessage.asus.com', 'gaming-config.asus.com', 'rog-content-platform.asus.com', 'nomos.asus.com',
        'dlcdnrog.asus.com', 'account.asus.com'
    foreach ($h in $hosts) { "0.0.0.0 $h" }
}
