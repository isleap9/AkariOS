# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): Microsoft Edge out of the
# image, WebView2 kept (Program Files (x86)\Microsoft\EdgeWebView and EdgeUpdate stay: apps and Windows' own pages
# need it, as Apps > Remove keeps it). The same folders and uninstall key zISO Tweaker removes (MIT, CREDITS.md).
@{
    Name        = 'Microsoft Edge'
    Description = 'The Edge browser removed. WebView2, which apps and Windows itself use, stays; install any browser afterwards.'
    Kind        = 'Files'
    Risk        = 'Caution'
    Order       = 5
    Apps        = @('Microsoft.MicrosoftEdge.Stable')
    Registry    = @(
        @{ Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'; Value = $null }
        # Edge Update doesn't put it back during setup
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\EdgeUpdate'; Value = $null }
    )
    Remove      = @(
        'Program Files (x86)\Microsoft\Edge'
        'Program Files (x86)\Microsoft\EdgeCore'
    )
}
