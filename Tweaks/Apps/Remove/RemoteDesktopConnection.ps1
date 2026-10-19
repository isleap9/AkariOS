# Action: Remote Desktop Connection comes back from its installer, not through an Akari Revert.
# Ported from FR33THY Ultimate "bloatware" (legacy apps).
@{
    Id          = 'remove-remote-desktop-connection'
    Name        = 'Remote Desktop Connection'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Caution'
    Description = 'The Remote Desktop client (mstsc), to connect to other PCs.'
    Detect      = { -not (Test-Path "$env:SystemRoot\System32\mstsc.exe") }
    Apply       = { Invoke-AkariSelfUninstall "$env:SystemRoot\System32\mstsc.exe" 'mstsc' }
}
