# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Updated Install", NVIDIA. NVIDIA's settings are
# graphics-nvidia-settings (and graphics-hdcp-off, graphics-p0-state), as in "Install & Settings".
# Action: a driver install, done by NVIDIA's own installer; DDU (tools-ddu-clean) removes it.
@{
    Id          = 'tools-driver-nvidia'
    Name        = 'Install latest NVIDIA driver'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Requires    = 'NVIDIA'
    Description = 'Downloads the latest WHQL GeForce driver from NVIDIA and starts its installer. Then apply NVIDIA settings (Graphics & Hardware). In NVIDIA App, turn off statistics, game filters and automatic game optimization.'
    Apply       = {
        . "$AkariTweakDir\Files\Drivers.ps1"
        $exe = "$env:SystemRoot\Temp\nvidiadriver.exe"
        Invoke-WebRequest -Uri (Get-DriverNvidiaUrl) -OutFile $exe -UseBasicParsing
        Start-Process -FilePath $exe
    }
}
