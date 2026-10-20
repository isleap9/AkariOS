# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-helium'
    Name        = 'Helium'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Browsers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Private Chromium-based web browser. Akari turns off hardware acceleration and background mode, and removes its updaters.'
    Winget      = 'ImputNet.Helium'
    After       = {
        $p = 'HKLM:\SOFTWARE\Policies\Helium'
        Set-Reg $p 'HardwareAccelerationModeEnabled' 0
        Set-Reg $p 'BackgroundModeEnabled' 0
        Set-Reg $p 'HighEfficiencyModeEnabled' 1
        Remove-AkariUpdaters 'Helium'
    }
}
