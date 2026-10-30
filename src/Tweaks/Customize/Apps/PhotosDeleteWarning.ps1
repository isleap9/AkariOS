# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Do not show delete photo warning in
# Photos App": a value in the Photos app's own settings hive, typed 0x5f5e10b (first byte 1 = don't ask, then
# ZOICWARE's timestamp). Revert deletes it. Detect reads a copy of that hive: Unknown while Photos runs.
@{
    Id          = 'apps-photos-no-delete-warning'
    Name        = 'Photos: no question before deleting'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Deleting a picture in the Photos app sends it to the Recycle Bin without asking first. Close Photos before changing this.'
    Detect      = {
        Get-AkariAppSettingState 'Microsoft.Windows.Photos_8wekyb3d8bbwe' @(@{ Name = 'LocalState\DeleteConfirmationDialogStatus'; Value = 1; Default = 0 })
    }
    Apply       = {
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState]`r`n""DeleteConfirmationDialogStatus""=hex(5f5e10b):01,3c,82,63,f2,31,e0,dc,01`r`n"
        if (-not (Import-AkariAppSettings 'Microsoft.Windows.Photos_8wekyb3d8bbwe' $reg)) { throw 'the Photos app''s settings could not be opened (close Photos, or open it once if it never ran)' }
    }
    Revert      = {
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState]`r`n""DeleteConfirmationDialogStatus""=-`r`n"
        if (-not (Import-AkariAppSettings 'Microsoft.Windows.Photos_8wekyb3d8bbwe' $reg)) { throw 'the Photos app''s settings could not be opened (close Photos)' }
    }
}
