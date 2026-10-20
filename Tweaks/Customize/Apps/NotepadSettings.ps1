# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Notepad Settings" (One-click: steptwo.ps1). The values
# live in Notepad's own settings hive (Import-AkariAppSettings); its Default deletes that file, so Notepad starts over
# with its own defaults. No Detect: the hive can't be read while Notepad runs.
@{
    Id          = 'apps-notepad-settings'
    Name        = 'Notepad: new window, no session restore, no AI rewrite'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Files open in a new window instead of a tab, Notepad doesn''t reopen your last session, and the Copilot rewrite is off.'
    Apply       = {
        Stop-Process -Name Notepad -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState]`r`n" +
            "`"OpenFile`"=hex(5f5e104):01,00,00,00,d1,55,24,57,d1,84,db,01`r`n" +
            "`"GhostFile`"=hex(5f5e10b):00,42,60,f1,5a,d1,84,db,01`r`n" +
            "`"RewriteEnabled`"=hex(5f5e10b):00,12,4a,7f,5f,d1,84,db,01`r`n"
        if (-not (Import-AkariAppSettings 'Microsoft.WindowsNotepad_8wekyb3d8bbwe' $reg)) { throw 'Notepad''s settings could not be opened (open Notepad once, then try again)' }
    }
    Revert      = {
        Stop-Process -Name Notepad -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $dat = Join-Path (Get-AkariUserFolder 'Local AppData') 'Packages\Microsoft.WindowsNotepad_8wekyb3d8bbwe\Settings\settings.dat'
        if (Test-Path -LiteralPath $dat) { Remove-Item -LiteralPath $dat -Force }
    }
}
