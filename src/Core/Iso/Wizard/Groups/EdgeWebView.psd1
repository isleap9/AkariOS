# ISO Builder removal group, ported from Tiny11 Builder (ntdevlabs, used with its developers' permission: ADR 0010,
# docs/permissions/tiny11builder.md) at commit 38f7ab6b1f177098c026a19b73ec84bca9c4b874: src/Tiny11Builder.Core/ImageOperations.cs
# RemoveOriginalFiles ("edge-files") and EdgeRegistration.cs.
@{
    Name        = 'Microsoft Edge and WebView2'
    Description = 'Edge and WebView2 removed, files and all. Apps and Windows pages that need WebView2 stop working until it is installed again (Downloads). Updates may put Edge back.'
    Kind        = 'Files'
    Risk        = 'Advanced'
    Order       = 6
    Registry    = @(
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView'; Value = $null }
        @{ Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'; Value = $null }
        @{ Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update'; Value = $null }
        @{ Path = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\EdgeUpdate'; Value = $null }
    )
    Remove      = @(
        'Program Files\Microsoft\Edge'
        'Program Files\Microsoft\EdgeCore'
        'Program Files\Microsoft\EdgeUpdate'
        'Program Files\Microsoft\EdgeWebView'
        'Program Files (x86)\Microsoft\Edge'
        'Program Files (x86)\Microsoft\EdgeCore'
        'Program Files (x86)\Microsoft\EdgeUpdate'
        'Program Files (x86)\Microsoft\EdgeWebView'
        'Windows\System32\Microsoft-Edge-Webview'
        'Windows\WinSxS\*microsoft-edge-webview*'
    )
}
