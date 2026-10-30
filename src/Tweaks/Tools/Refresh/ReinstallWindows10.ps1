# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "Reinstall" (W10). Microsoft's own Media Creation Tool,
# from Microsoft's download link (no longer a copy on AkariOS-Files).
# Action: it downloads and starts Microsoft's tool, which asks before it changes anything.
@{
    Id          = 'tools-reinstall-windows-10'
    Name        = 'Reinstall Windows 10'
    Section     = 'Tools'
    Category    = 'Refresh'
    Kind        = 'Action'
    Button      = 'Download'
    Risk        = 'Safe'
    Description = 'Downloads and starts Microsoft''s Media Creation Tool for Windows 10: upgrade this PC or make an install USB.'
    Apply       = {
        $exe = "$env:SystemRoot\Temp\MediaCreationTool_Win10.exe"
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?LinkId=691209' -OutFile $exe -UseBasicParsing
        Start-Process -FilePath $exe
    }
}
