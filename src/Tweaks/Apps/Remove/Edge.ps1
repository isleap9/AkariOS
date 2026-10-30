# Action: Edge comes back from Microsoft's installer (or winget), not through an Akari Revert.
# Ported from FR33THY Ultimate "Edge and WebView" (6 Windows), split: this removes the browser only; WebView2 and
# Edge Update stay for the apps that need them (WebView2.ps1 removes those).
@{
    Id          = 'remove-edge'
    Name        = 'Microsoft Edge'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Caution'
    Description = 'The Edge browser only. WebView2, which some apps need, stays. Install another browser first.'
    Detect      = { -not (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") }
    Apply       = {
        Get-Process | Where-Object { $_.ProcessName -like 'msedge*' -and $_.ProcessName -ne 'msedgewebview2' } | Stop-Process -Force -ErrorAction SilentlyContinue
        # Edge's uninstaller refuses unless uninstalling is allowed and this (empty) legacy Edge file exists
        Set-Reg 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev' 'AllowUninstall' 1
        $legacy = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
        New-Item "$legacy\MicrosoftEdge.exe" -ItemType File -Force | Out-Null
        $u = Get-AkariRegValue 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge' 'UninstallString'
        if ($u) { Start-Process 'cmd.exe' -ArgumentList "/c $u --force-uninstall" -WindowStyle Hidden -Wait }
        Remove-Item $legacy -Recurse -Force -ErrorAction SilentlyContinue
        # Edge Update must not put it back (WebView2 keeps updating)
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'DoNotUpdateToEdgeWithChromium' 1
        # leftovers: folder, uninstall entry, shortcuts, elevation service
        Remove-Item "${env:ProgramFiles(x86)}\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge' -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:PUBLIC\Desktop\Microsoft Edge.lnk", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$(Get-AkariUserFolder 'AppData')\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
        foreach ($s in @(Get-Service -Name 'MicrosoftEdgeElevationService' -ErrorAction SilentlyContinue)) { Stop-Service $s.Name -Force -ErrorAction SilentlyContinue; Remove-AkariService $s.Name }
        # Windows 10: the old built-in Edge package
        $pkg = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages' -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like '*Microsoft-Windows-Internet-Browser-Package*~~*' }).PSChildName
        foreach ($p in @($pkg | Where-Object { $_ })) {
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\$p" 'Visibility' 1
            Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\$p\Owners" -Recurse -Force -ErrorAction SilentlyContinue
            Start-Process 'dism.exe' -ArgumentList "/online /Remove-Package /PackageName:$p /quiet /norestart" -WindowStyle Hidden -Wait
        }
        # WebView2 already gone too: Edge Update has nothing left to update (same steps as WebView2.ps1)
        if (-not (Test-Path "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application")) {
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
