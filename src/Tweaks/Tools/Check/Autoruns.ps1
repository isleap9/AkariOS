# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Autoruns Startup Tasks & Apps Check": the Autoruns part
# (Sysinternals Autoruns, now from winget). Its cleanup part is oneclick-startup-cleanup (Tools > Cleanup).
# Action: it opens a tool; it changes nothing.
@{
    Id          = 'tools-autoruns'
    Name        = 'Startup apps and tasks check (Autoruns)'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Check'
    Risk        = 'Safe'
    Description = 'Opens Sysinternals Autoruns (installed first if missing): everything that starts with Windows, to untick what you don''t need.'
    Apply       = { Open-AkariWingetTool 'Microsoft.Sysinternals.Autoruns' 'Autoruns64.exe' }
}
