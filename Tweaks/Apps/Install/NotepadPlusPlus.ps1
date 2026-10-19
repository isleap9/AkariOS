# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-notepad'
    Name        = 'Notepad++'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Utilities'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Text and code editor. Akari sets dark mode, no auto-update, no session restore and no recent files.'
    Winget      = 'Notepad++.Notepad++'
    After       = {
        # Akari's config (Files\NotepadPlusPlus\config.xml), for the real user
        $dir = Join-Path (Get-AkariUserFolder 'AppData') 'Notepad++'
        New-Item $dir -ItemType Directory -Force | Out-Null
        Copy-Item "$AkariTweakDir\Files\NotepadPlusPlus\config.xml" "$dir\config.xml" -Force
    }
}
