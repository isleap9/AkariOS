# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Bloatware Legacy Apps Check" (it opens Programs and
# Features).
# Action: it opens a window and changes nothing.
@{
    Id          = 'tools-installed-programs'
    Name        = 'Installed programs'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Programs and Features, to check what is still installed after a debloat and uninstall the rest.'
    Apply       = { Start-Process 'appwiz.cpl' }
}
