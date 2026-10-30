# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Bloatware Legacy Features Check" and the Bloatware
# group's "Legacy features" (both open Windows Features).
# Action: it opens a window; Windows' own dialog makes the changes.
@{
    Id          = 'tools-windows-features'
    Name        = 'Windows features'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens "Turn Windows features on or off", to check or bring back a feature the debloat turned off.'
    Apply       = { Start-Process 'optionalfeatures.exe' }
}
