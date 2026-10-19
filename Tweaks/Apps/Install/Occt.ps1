# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-occt'
    Name        = 'OCCT'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'CPU, GPU, RAM and power supply stress tests. With a Start-menu shortcut.'
    Winget      = 'OCBase.OCCT.Personal'
    # portable package: no Start-menu entry of its own
    After       = { $exe = Get-AkariWingetExe 'OCBase.OCCT.Personal' 'OCCT*.exe'; if ($exe) { New-AkariShortcut 'OCCT' $exe } }
}
