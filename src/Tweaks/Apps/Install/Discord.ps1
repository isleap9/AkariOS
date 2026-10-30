# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-discord'
    Name        = 'Discord'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Communication'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Voice and text chat. Akari turns off hardware acceleration and stops it from starting with Windows.'
    Winget      = 'Discord.Discord'
    After       = {
        # winget returns while Discord's own installer (Squirrel's Update.exe) is still installing: wait for it to end,
        # never stop it (that aborts the install). It then starts Discord: close only Discord, so it does not write
        # over the settings.
        Start-Sleep -Seconds 5
        Get-Process -Name 'Update' -ErrorAction SilentlyContinue | Where-Object { "$($_.Path)" -like '*\Discord\*' } |
            Wait-Process -Timeout 300 -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        Stop-Process -Name 'Discord' -Force -ErrorAction SilentlyContinue
        $dir = Join-Path (Get-AkariUserFolder 'AppData') 'discord'
        New-Item $dir -ItemType Directory -Force | Out-Null
        Set-Content "$dir\settings.json" -Force -Value @'
{
    "SKIP_HOST_UPDATE": true,
    "DEVELOPER_MODE": true,
    "enableHardwareAcceleration": false,
    "MINIMIZE_TO_TRAY": true,
    "OPEN_ON_STARTUP": false,
    "START_MINIMIZED": false,
    "IS_MAXIMIZED": true,
    "IS_MINIMIZED": false,
    "debugLogging": false
}
'@
        Remove-AkariStartup 'Discord'
    }
}
