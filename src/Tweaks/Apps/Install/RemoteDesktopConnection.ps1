# Action: an installed app is removed with its own uninstaller (or the Apps step's Remove tab); Akari has no Revert for it.
# Not winget: winget has the new Remote Desktop app, not Windows' Remote Desktop Connection (mstsc); its installer
# comes from the AkariOS-Files release. Ported from FR33THY Ultimate "bloatware" (Install: Remote Desktop Connection).
@{
    Id          = 'install-remote-desktop-connection'
    Name        = 'Remote Desktop Connection'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Restore removed apps'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Brings Windows'' Remote Desktop Connection (mstsc) back after a debloat.'
    Detect      = { Test-Path "$env:SystemRoot\System32\mstsc.exe" }
    Apply       = {
        $exe = Save-AkariFile 'remotedesktopconnection.exe' "$env:SystemRoot\Temp\remotedesktopconnection.exe"
        Start-Process -FilePath $exe -Wait
    }
}
