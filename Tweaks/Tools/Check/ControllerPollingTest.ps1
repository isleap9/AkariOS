# Ported from AkariOS-Ultimate (FR33THY Ultimate) 7 Hardware "Controller Polling Rate Test" (Gamepadla's Polling).
# Not winget: Polling has no package; it comes from the AkariOS-Files release.
# Action: it installs and opens a test tool; it changes no setting.
@{
    Id          = 'tools-controller-polling-test'
    Name        = 'Controller polling rate test'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Gamepadla''s Polling (downloaded the first time, with a Start-menu shortcut): measures your controller''s real polling rate.'
    Apply       = {
        $exe = "${env:ProgramFiles(x86)}\Polling\Polling.exe"
        if (-not (Test-Path -LiteralPath $exe)) { [void](Save-AkariFile 'polling.exe' $exe) }
        New-AkariShortcut 'Polling' $exe
        Start-Process -FilePath $exe
    }
}
