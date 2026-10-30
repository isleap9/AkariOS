# Action: an installed app is removed with its own uninstaller (Apps > Remove > Microsoft Edge WebView2); Akari has no Revert for it.
# Puts WebView2 back after the removal (the Default of the legacy "Edge and WebView" row).
@{
    Id          = 'install-webview2-runtime'
    Name        = 'Microsoft Edge WebView2 Runtime'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Runtimes'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'The runtime many apps draw their windows with (Teams, Widgets, some launchers and game overlays).'
    Winget      = 'Microsoft.EdgeWebView2Runtime'
    # the WebView2 removal (Tweaks\Apps\Remove\WebView2.ps1) blocks Edge Update from installing it: lift that first
    Before      = { Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' }
}
