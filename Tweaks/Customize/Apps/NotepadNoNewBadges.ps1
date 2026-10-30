# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Disable Notepad Tabs and Rewrite": its
# GenerateNewBadgeLifetime value (the rest are apps-notepad-settings'), in Notepad's own settings hive, typed 0x5f5e105
# (a number 0, then ZOICWARE's timestamp). Revert deletes it. Detect reads a copy of the hive: Unknown while Notepad runs.
@{
    Id          = 'apps-notepad-no-new-badges'
    Name        = 'Notepad: no "New" badges'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    Requires    = 'Win11'
    Guided      = $false
    Description = 'Notepad stops marking its new features with "New" badges. Close Notepad before changing this.'
    Detect      = {
        Get-AkariAppSettingState 'Microsoft.WindowsNotepad_8wekyb3d8bbwe' @(@{ Name = 'LocalState\GenerateNewBadgeLifetime'; Value = 0; Default = 1 })
    }
    Apply       = {
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState]`r`n""GenerateNewBadgeLifetime""=hex(5f5e105):00,00,00,00,4e,05,87,c4,dc,bb,dc,01`r`n"
        if (-not (Import-AkariAppSettings 'Microsoft.WindowsNotepad_8wekyb3d8bbwe' $reg)) { throw 'Notepad''s settings could not be opened (close Notepad, or open it once if it never ran)' }
    }
    Revert      = {
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState]`r`n""GenerateNewBadgeLifetime""=-`r`n"
        if (-not (Import-AkariAppSettings 'Microsoft.WindowsNotepad_8wekyb3d8bbwe' $reg)) { throw 'Notepad''s settings could not be opened (close Notepad)' }
    }
}
