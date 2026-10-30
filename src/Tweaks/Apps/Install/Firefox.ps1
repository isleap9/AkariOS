# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-firefox'
    Name        = 'Firefox'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Web browser. Akari adds uBlock Origin, turns off hardware acceleration and auto-updates, and removes the Mozilla Maintenance Service.'
    Winget      = 'Mozilla.Firefox'
    After       = {
        $u = "${env:ProgramFiles(x86)}\Mozilla Maintenance Service\uninstall.exe"
        if (Test-Path $u) { Start-Process $u -ArgumentList '/S' -WindowStyle Hidden -Wait }
        Remove-AkariUpdaters 'Firefox'
        # uBlock Origin for every profile: an extension in Firefox's distribution folder
        $ext = "$env:ProgramFiles\Mozilla Firefox\distribution\extensions"
        New-Item $ext -ItemType Directory -Force | Out-Null
        Invoke-WebRequest 'https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi' -OutFile "$ext\uBlock0@raymondhill.net.xpi" -UseBasicParsing
        # policies instead of a profile's user.js: they apply to every profile, including ones made later
        Set-Reg 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox' 'AppAutoUpdate' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Mozilla\Firefox' 'HardwareAcceleration' 0
        Remove-AkariStartup '*Firefox*'
    }
}
