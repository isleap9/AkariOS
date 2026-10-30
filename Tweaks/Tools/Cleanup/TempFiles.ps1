# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Clear TEMP Cache" (Ultimate Cleanup):
# Windows' Temp folder and the real user's (ZOICWARE took the elevated one's).
# Action: nothing to put back.
@{
    Id          = 'cleanup-temp-files'
    Name        = 'Delete temporary files'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Empties the Windows Temp folder and yours. Files open in a program stay.'
    Confirm     = 'Delete everything in the Windows and user Temp folders? Close running installers first.'
    Apply       = {
        $n = Remove-AkariPaths @("$env:SystemRoot\Temp\*", "$(Get-AkariUserFolder 'Local AppData')\Temp\*")
        "Deleted $n temporary files and folders"
    }
}
