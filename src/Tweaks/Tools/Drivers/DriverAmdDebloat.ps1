# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Debloat Install & Settings", AMD. The full
# package comes from the user's Downloads folder instead of a file picker. Its settings are graphics-amd-settings.
# Action: a driver install; DDU (tools-ddu-clean) removes it.
@{
    Id          = 'tools-driver-amd-debloat'
    Name        = 'Install latest AMD driver, debloated'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Requires    = 'AMD'
    Reboot      = $true
    Description = 'Installs the newest full Adrenalin package in your Downloads folder (download it from AMD first) with its extras off, then removes Crash Defender, the audio co-processor drivers, the bug report tool, Install Manager and their startup entries.'
    Apply       = {
        . "$AkariTweakDir\Files\Drivers.ps1"
        $pkg = Get-DriverPackage '*amd-software-adrenalin-edition*.exe' '*minimalsetup*' 'https://www.amd.com/en/support/download/drivers.html' 'AMD'
        $dir = "$env:SystemRoot\Temp\amddriver"
        Expand-DriverArchive $pkg $dir
        # the optional parts: not installed, not offered
        foreach ($x in 'AMDAUEPInstaller', 'AMDCOMPUTE', 'AMDLinkDriverUpdate', 'AMDRELAUNCHER', 'AMDScoSupportTypeUpdate', 'AMDUpdater', 'AMDUWPLauncher',
            'EnableWindowsDriverSearch', 'InstallUEP', 'ModifyLinkUpdate') {
            $f = "$dir\Config\$x.xml"
            if (Test-Path -LiteralPath $f) { Set-Content -LiteralPath $f -Value ((Get-Content -LiteralPath $f -Raw) -replace '<Enabled>true</Enabled>', '<Enabled>false</Enabled>' -replace '<Hidden>true</Hidden>', '<Hidden>false</Hidden>') -NoNewline }
        }
        foreach ($f in "$dir\Config\InstallManifest.json", "$dir\Bin64\cccmanifest_64.json") {
            if (Test-Path -LiteralPath $f) { Set-Content -LiteralPath $f -Value ((Get-Content -LiteralPath $f -Raw) -replace '"InstallByDefault"\s*:\s*"Yes"', '"InstallByDefault" : "No"') -NoNewline }
        }
        Write-Log 'Installing the AMD driver'
        $code = Invoke-AkariExe "$dir\Bin64\ATISetup.exe" @('-INSTALL', '-VIEW:2')
        if ($code -ne 0) { Write-Log "AMD setup exit code: $code" }
        Remove-AkariStartup 'AMDNoiseSuppression'
        Remove-AkariStartup 'StartRSX' @('HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
        Unregister-ScheduledTask -TaskName 'StartCN' -Confirm:$false -ErrorAction SilentlyContinue
        Remove-DriverServices 'AMD Crash Defender Service', 'amdfendr', 'amdfendrmgr', 'amdacpbus', 'AMDSAFD', 'AtiHDAudioService'
        Remove-Item -LiteralPath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\AMD Bug Report Tool", "$env:SystemRoot\SysWOW64\AMDBugReportTool.exe" -Recurse -Force -ErrorAction SilentlyContinue
        Uninstall-AkariMsi '*AMD Install Manager*'
        Remove-Item -LiteralPath $pkg, $dir, "$env:SystemDrive\AMD" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
