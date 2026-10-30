# Action: an installed app is removed with its own uninstaller (Apps > Remove > Microsoft Edge); Akari has no Revert for it.
# Puts Edge back after the removal (the Default of the legacy "Edge and WebView" row).
@{
    Id          = 'install-microsoft-edge'
    Name        = 'Microsoft Edge'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Microsoft''s web browser, for when you removed it and need it back.'
    Winget      = 'Microsoft.Edge'
    # the Edge removal (Tweaks\Apps\Remove\Edge.ps1) blocks Edge Update from installing Edge: lift that first
    Before      = {
        Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
        Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'DoNotUpdateToEdgeWithChromium'
    }
}
