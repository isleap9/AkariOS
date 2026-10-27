# Action: an installed app is removed with its own uninstaller (or the Apps step's Remove tab); Akari has no Revert for it.
# Not winget: Windows 10's Snipping Tool is no package; its installer comes from the AkariOS-Files release (the new
# Snipping Tool is a Store app: store/Microsoft.ScreenSketch). Ported from FR33THY Ultimate "bloatware" (Install:
# Snipping Tool).
@{
    Id          = 'install-snipping-tool-legacy'
    Name        = 'Snipping Tool (Windows 10)'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Restore removed apps'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Brings the classic Snipping Tool back after a debloat. The new one is in this card as a Store app while it is missing.'
    Detect      = { Test-Path "$env:SystemRoot\System32\SnippingTool.exe" }
    Apply       = {
        $exe = Save-AkariFile 'snippingtool.exe' "$env:SystemRoot\Temp\snippingtool.exe"
        Start-Process -FilePath $exe -Wait
    }
}
