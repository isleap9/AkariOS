# Action: WebView2 comes back from Microsoft's installer (or winget), not through an Akari Revert.
# Ported from FR33THY Ultimate "Edge and WebView" (6 Windows), split: this removes the WebView2 runtime, and Edge
# Update once Edge is gone too. Kept out of the AkariOS pick: apps built on WebView2 stop working without it.
@{
    Id          = 'remove-webview2'
    Name        = 'Microsoft Edge WebView2'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Advanced'
    Keep        = $true
    Confirm     = 'Remove WebView2? Apps built on it stop working (Teams, Widgets, some launchers and game overlays) until you install it again.'
    Description = 'The runtime many apps draw their windows with. Remove it only if none of your apps need it.'
    Detect      = { -not (Test-Path "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application") }
    Apply       = {
        Stop-Process -Name 'msedgewebview2' -Force -ErrorAction SilentlyContinue
        Set-Reg 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev' 'AllowUninstall' 1
        $u = Get-AkariRegValue 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView' 'UninstallString'
        if ($u) { Start-Process 'cmd.exe' -ArgumentList "/c $u --force-uninstall" -WindowStyle Hidden -Wait }
        # Edge Update must not put it back
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' 0
        Remove-Item "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView' -Recurse -Force -ErrorAction SilentlyContinue
        # Edge already gone too: Edge Update has nothing left to update (same steps as Edge.ps1)
        if (-not (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe")) {
            Get-Process -Name 'MicrosoftEdgeUpdate' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            foreach ($x in @(Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\*.*.*.*\MicrosoftEdgeUpdate.exe" -ErrorAction SilentlyContinue)) {
                Start-Process $x.FullName -ArgumentList '/unregsvc' -Wait
                Start-Process $x.FullName -ArgumentList '/uninstall' -Wait
            }
            foreach ($s in @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'edgeupdate*' })) { Stop-Service $s.Name -Force -ErrorAction SilentlyContinue; Remove-AkariService $s.Name }
            Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*EdgeUpdate*' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
            Remove-Item "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
