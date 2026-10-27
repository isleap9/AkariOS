# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Debloat Install & Settings", Intel. The package
# comes from the user's Downloads folder instead of a file picker. Its settings are graphics-intel-settings.
# Action: a driver install; DDU (tools-ddu-clean) removes it.
@{
    Id          = 'tools-driver-intel-debloat'
    Name        = 'Install latest Intel driver, debloated'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Requires    = 'Intel'
    Reboot      = $true
    Description = 'Installs the newest Intel graphics package (gfx_win_*.exe) in your Downloads folder with no extras, adds Intel Graphics Software without its startup entry, and removes the firmware update, HDCP and controller services.'
    Apply       = {
        . "$AkariTweakDir\Files\Drivers.ps1"
        $pkg = Get-DriverPackage 'gfx_win_*.exe' '' 'https://www.intel.com/content/www/us/en/search.html#sortCriteria=%40lastmodifieddt%20descending&f-operatingsystem_en=Windows%2011%20Family*&f-downloadtype=Drivers&cf-tabfilter=Downloads' 'Intel'
        $dir = "$env:SystemDrive\inteldriver"
        Expand-DriverArchive $pkg $dir
        Write-Log 'Installing the Intel driver'
        $code = Invoke-AkariExe "$dir\Installer.exe" @('-f', '--noExtras', '--terminateProcesses', '-s')
        if ($code -ne 0) { Write-Log "Intel installer exit code: $code" }
        $igs = Get-ChildItem -LiteralPath "$dir\Resources\Extras" -Filter 'IntelGraphicsSoftware_*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($igs) { [void](Invoke-AkariExe $igs.FullName @('/s')) }
        # "Intel(R) Graphics Software" (the registered sign, not ASCII)
        Remove-AkariStartup "Intel$([char]0xAE) Graphics Software"
        Remove-DriverServices 'IntelGFXFWupdateTool', 'cplspcon', 'CtaChildDriver', 'GSCAuxDriver', 'GSCx64'
        Stop-Process -Name 'IntelGraphicsSoftware', 'PresentMonService' -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $pkg, $dir, "$env:SystemDrive\Intel" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
