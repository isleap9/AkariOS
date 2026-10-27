# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Debloat Install & Settings", NVIDIA (and the
# driver-only install of "Driver Updated Install & Settings"): the latest driver is downloaded, not picked by hand.
# Its settings are graphics-nvidia-settings (and graphics-hdcp-off, graphics-p0-state).
# Action: a driver install; DDU (tools-ddu-clean) removes it.
@{
    Id          = 'tools-driver-nvidia-debloat'
    Name        = 'Install latest NVIDIA driver, debloated'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Requires    = 'NVIDIA'
    Reboot      = $true
    Description = 'Downloads the latest GeForce driver, strips NVIDIA App, telemetry, ShadowPlay, PhysX, HD Audio and the rest, installs the driver silently and adds the NVIDIA Control Panel. Then apply NVIDIA settings (Graphics & Hardware).'
    Apply       = {
        . "$AkariTweakDir\Files\Drivers.ps1"
        $exe = "$env:SystemRoot\Temp\nvidiadriver.exe"
        $dir = "$env:SystemRoot\Temp\nvidiadriver"
        Invoke-WebRequest -Uri (Get-DriverNvidiaUrl) -OutFile $exe -UseBasicParsing
        Expand-DriverArchive $exe $dir
        foreach ($p in 'Display.Nview', 'FrameViewSDK', 'HDAudio', 'MSVCRT', 'NvApp.MessageBus', 'NvBackend', 'NvContainer', 'NvCpl', 'NvDLISR',
            'NVPCF', 'NvTelemetry', 'NvVAD', 'PhysX', 'PPC', 'ShadowPlay', 'NvApp\CEF', 'NvApp\osc', 'NvApp\Plugins', 'NvApp\UpgradeConsent',
            'NvApp\www', 'NvApp\7z.dll', 'NvApp\7z.exe', 'NvApp\DarkModeCheck.exe', 'NvApp\InstallerExtension.dll', 'NvApp\NvApp.nvi',
            'NvApp\NvAppApi.dll', 'NvApp\NvAppExt.dll', 'NvApp\NvConfigGenerator.dll') {
            Remove-Item -LiteralPath "$dir\$p" -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Log 'Installing the NVIDIA driver'
        $code = Invoke-AkariExe "$dir\setup.exe" @('-s', '-noreboot', '-noeula', '-clean')
        if ($code -ne 0) { Write-Log "NVIDIA setup exit code: $code" }
        # the NVIDIA Control Panel (a Store app the stripped driver leaves out), from the AkariOS-Files release
        Add-AppxPackage -Path (Save-AkariFile 'nvp.appx' "$env:SystemRoot\Temp\nvp.appx")
        Remove-Item -LiteralPath $exe, "$env:SystemDrive\NVIDIA" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
