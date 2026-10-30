# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# Not winget: winget's package is portable (no Start-menu shortcut); Akari's build is a single .exe.
@{
    Id          = 'install-nvidia-profile-inspector'
    Name        = 'NVIDIA Profile Inspector'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Edits NVIDIA driver profiles, including settings the NVIDIA Control Panel hides. With a Start-menu shortcut.'
    Detect      = { Test-Path "${env:ProgramFiles(x86)}\Nvidia Profile Inspector\Nvidia Profile Inspector.exe" }
    Apply       = { New-AkariShortcut 'Nvidia Profile Inspector' (Save-AkariFile 'inspector.exe' "${env:ProgramFiles(x86)}\Nvidia Profile Inspector\Nvidia Profile Inspector.exe") }
}
