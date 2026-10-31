# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Remove-Edge. Unlike zISO, WebView2 stays (Program Files (x86)\Microsoft\EdgeWebView and EdgeUpdate, the WinSxS
# and System32 Edge-Webview folders): Akari keeps it everywhere (Apps › Remove: WebView2 is Keep), apps and Windows
# pages break without it.
@{
    Name        = 'Remove Microsoft Edge'
    Description = 'Removes the Edge browser from the image. WebView2, which apps and Windows itself use, stays.'
    Group       = 'Apps'
    Order       = 1
    Registry    = @(
        @{ Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'; Value = $null }
    )
    Remove      = @(
        'Program Files (x86)\Microsoft\Edge'
        'Program Files (x86)\Microsoft\EdgeCore'
    )
}
