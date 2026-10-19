# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# Not winget: the NVIDIA App is not on winget.
@{
    Id          = 'install-nvidia-app'
    Name        = 'NVIDIA App'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'NVIDIA''s driver and graphics settings app.'
    Apply       = {
        $exe = Save-AkariFile 'nvidiaapp.exe' "$env:SystemRoot\Temp\nvidiaapp.exe"
        Start-Process $exe -ArgumentList '/s' -Wait
    }
}
