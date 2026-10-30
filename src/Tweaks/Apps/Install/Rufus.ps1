# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-rufus'
    Name        = 'Rufus'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Makes bootable USB drives. With a Start-menu shortcut.'
    Winget      = 'Rufus.Rufus'
    # portable package: no Start-menu entry of its own
    After       = { $exe = Get-AkariWingetExe 'Rufus.Rufus' 'rufus*.exe'; if ($exe) { New-AkariShortcut 'Rufus' $exe } }
}
