# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# Not winget: winget has CRU alone, without Scaled Resolution Editor, and no Start-menu shortcut (portable package).
@{
    Id          = 'install-custom-resolution-utility'
    Name        = 'Custom Resolution Utility'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'ToastyX''s Custom Resolution Utility and Scaled Resolution Editor, with Start-menu shortcuts.'
    Detect      = { (Test-Path "${env:ProgramFiles(x86)}\CRUSRE\CRU.exe") -and (Test-Path "${env:ProgramFiles(x86)}\CRUSRE\SRE.exe") }
    Apply       = {
        $dir = "${env:ProgramFiles(x86)}\CRUSRE"
        New-AkariShortcut 'Custom Resolution Utility' (Save-AkariFile 'cru.exe' "$dir\CRU.exe")
        New-AkariShortcut 'Scaled Resolution Editor' (Save-AkariFile 'sre.exe' "$dir\SRE.exe")
    }
}
