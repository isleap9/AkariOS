# Ported from AkariOS-Ultimate (FR33THY Ultimate) 7 Hardware "Mouse Polling Rate Test".
# Not winget: Mouse Movement Recorder has no package; it comes from the AkariOS-Files release.
# Action: it installs and opens a test tool; it changes no setting.
@{
    Id          = 'tools-mouse-polling-test'
    Name        = 'Mouse polling rate test'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Mouse Movement Recorder (downloaded the first time, with a Start-menu shortcut): move the mouse fast to see its real polling rate.'
    Apply       = {
        $exe = "${env:ProgramFiles(x86)}\Mouse Movement Recorder\Mouse Movement Recorder.exe"
        if (-not (Test-Path -LiteralPath $exe)) { [void](Save-AkariFile 'mousemovementrecorder.exe' $exe) }
        New-AkariShortcut 'Mouse Movement Recorder' $exe
        Start-Process -FilePath $exe
    }
}
