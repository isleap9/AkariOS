# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# Not winget: winget's package is portable (no Start-menu shortcut); Akari's build is a single .exe.
@{
    Id          = 'install-onboard-memory-manager'
    Name        = 'Logitech Onboard Memory Manager'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Sets up a Logitech mouse''s on-board memory without G HUB running. With a Start-menu shortcut.'
    Detect      = { Test-Path "${env:ProgramFiles(x86)}\Onboard Memory Manager\Onboard Memory Manager.exe" }
    Apply       = { New-AkariShortcut 'Onboard Memory Manager' (Save-AkariFile 'omm.exe' "${env:ProgramFiles(x86)}\Onboard Memory Manager\Onboard Memory Manager.exe") }
}
