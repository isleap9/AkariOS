# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Clean", DDU: Manual. Prepare gets DDU ready while
# the network is up; in Safe Mode its own window opens, and the Run goes on (back to normal) once it is closed.
# Action: it opens a tool; what DDU removes can't be put back.
@{
    Id          = 'tools-ddu-manual'
    Name        = 'DDU in Safe Mode (manual)'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Advanced'
    SafeMode    = $true
    Description = 'Restarts into Safe Mode and opens Display Driver Uninstaller, to pick what it removes. Close DDU when done (or use its own restart button) and Akari restarts back to normal.'
    Prepare     = { . "$AkariTweakDir\Files\Drivers.ps1"; Initialize-DriverDdu }
    Apply       = {
        . "$AkariTweakDir\Files\Drivers.ps1"
        Start-Process -FilePath (Get-DriverDdu) -Wait
    }
}
