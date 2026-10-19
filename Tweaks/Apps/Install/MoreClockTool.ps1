# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# Not winget: More Clock Tool is not on winget.
@{
    Id          = 'install-more-clock-tool'
    Name        = 'More Clock Tool'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'AMD GPU clock and power tuning tool, with a Start-menu shortcut.'
    Detect      = { Test-Path "${env:ProgramFiles(x86)}\More Clock Tool\More Clock Tool.exe" }
    Apply       = { New-AkariShortcut 'More Clock Tool' (Save-AkariFile 'moreclocktool.exe' "${env:ProgramFiles(x86)}\More Clock Tool\More Clock Tool.exe") }
}
