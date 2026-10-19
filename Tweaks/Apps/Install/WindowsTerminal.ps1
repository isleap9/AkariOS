# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-windows-terminal'
    Name        = 'Windows Terminal'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Dev tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Terminal for PowerShell, cmd and WSL.'
    Winget      = 'Microsoft.WindowsTerminal'
}
