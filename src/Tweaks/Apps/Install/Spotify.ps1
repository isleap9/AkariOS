# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# Not winget: Spotify refuses to install elevated; Akari starts its installer through Explorer, as the signed-in user.
@{
    Id          = 'install-spotify'
    Name        = 'Spotify'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Music streaming. Akari turns off hardware acceleration and stops it from starting with Windows.'
    Detect      = { Test-Path (Join-Path (Get-AkariUserFolder 'AppData') 'Spotify\Spotify.exe') }
    Apply       = {
        # settings first: the installer starts Spotify, which reads them
        $dir = Join-Path (Get-AkariUserFolder 'AppData') 'Spotify'
        New-Item $dir -ItemType Directory -Force | Out-Null
        Set-Content "$dir\prefs" -Force -Value @'
app.autostart-configured=true
app.autostart-mode="off"
ui.hardware_acceleration=false
'@
        # a folder every user can read: Explorer runs the installer as the signed-in user
        $exe = Save-AkariFile 'spotify.exe' "$env:PUBLIC\Downloads\SpotifySetup.exe"
        Start-Process 'explorer.exe' -ArgumentList "`"$exe`""
        Start-Sleep -Seconds 10
        # wait for the installer only: Spotify itself keeps running afterwards
        Get-Process -Name 'SpotifySetup' -ErrorAction SilentlyContinue | Wait-Process -Timeout 600 -ErrorAction SilentlyContinue
    }
}
