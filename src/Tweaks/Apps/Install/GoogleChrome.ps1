# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# Google.Chrome.EXE, not Google.Chrome: that one's installer is Google's "latest" enterprise MSI, a URL Google replaces
# with every Chrome release, so winget refuses it (hash mismatch) until its manifest catches up. The EXE package
# points at a versioned file.
@{
    Id          = 'install-google-chrome'
    Name        = 'Google Chrome'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Web browser. Akari adds uBlock Origin Lite, turns off hardware acceleration and background mode, and removes Google''s updaters.'
    Winget      = 'Google.Chrome.EXE'
    After       = {
        $p = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
        Set-Reg "$p\ExtensionInstallForcelist" '1' 'ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx' 'String'
        Set-Reg $p 'HardwareAccelerationModeEnabled' 0
        Set-Reg $p 'BackgroundModeEnabled' 0
        Set-Reg $p 'HighEfficiencyModeEnabled' 1
        Remove-AkariUpdaters 'Google' 'Chrome'
    }
}
