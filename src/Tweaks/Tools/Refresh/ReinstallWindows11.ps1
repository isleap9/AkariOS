# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "Reinstall" (W11). Microsoft's own Media Creation Tool,
# from Microsoft's download link (no longer a copy on AkariOS-Files).
# Action: it downloads and starts Microsoft's tool, which asks before it changes anything.
@{
    Id          = 'tools-reinstall-windows-11'
    Name        = 'Reinstall Windows 11'
    Section     = 'Tools'
    Category    = 'Refresh'
    Kind        = 'Action'
    Button      = 'Download'
    Risk        = 'Safe'
    Description = 'Downloads and starts Microsoft''s Media Creation Tool for Windows 11: make an install USB or an ISO.'
    Apply       = {
        $exe = "$env:SystemRoot\Temp\MediaCreationTool_Win11.exe"
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2156295' -OutFile $exe -UseBasicParsing
        Start-Process -FilePath $exe
    }
}
