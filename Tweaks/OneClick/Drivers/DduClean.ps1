# From One-click's stepone.ps1 (isleap9/Akari-OS): DDU removes the GPU and audio drivers in Safe Mode, then restarts the
# PC (Restarts).
# Action: removed drivers can't be put back; Windows or the driver installer brings fresh ones.
@{
    Id          = 'oneclick-ddu-clean'
    Name        = 'Remove GPU and audio drivers (DDU)'
    Section     = 'OneClick'
    Category    = 'Drivers'
    Kind        = 'Action'
    Risk        = 'Advanced'
    SafeMode    = $true
    Restarts    = $true
    Description = 'Display Driver Uninstaller removes NVIDIA, AMD and Intel GPU drivers and Realtek / Sound Blaster audio drivers, then restarts.'
    Apply       = {
        $exe = "$env:SystemRoot\Temp\ddu\Display Driver Uninstaller.exe"
        # not prepared (its download failed): keep the drivers, the Run goes on after Akari's own restart
        if (-not (Test-Path -LiteralPath $exe)) { 'DDU is not ready (oneclick-ddu-prepare): the drivers stay'; return }
        Start-Process -FilePath $exe -ArgumentList '-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart' -Wait
    }
}
