# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Clean", DDU: Auto. The same DDU run as One-click
# (oneclick-ddu-prepare / oneclick-ddu-clean): Prepare gets DDU ready while the network is up, Safe Mode runs it.
# Action: removed drivers can't be put back; the driver installers bring fresh ones.
@{
    Id          = 'tools-ddu-clean'
    Name        = 'Clean GPU and audio drivers (DDU)'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Advanced'
    SafeMode    = $true
    Restarts    = $true
    Description = 'Restarts into Safe Mode, where Display Driver Uninstaller removes every GPU driver (NVIDIA, AMD, Intel) and the Realtek / Sound Blaster audio drivers, then restarts. Install a driver afterwards.'
    Prepare     = { . "$AkariTweakDir\Files\Drivers.ps1"; Initialize-DriverDdu }
    Apply       = {
        . "$AkariTweakDir\Files\Drivers.ps1"
        Start-Process -FilePath (Get-DriverDdu) -ArgumentList '-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart' -Wait
    }
}
