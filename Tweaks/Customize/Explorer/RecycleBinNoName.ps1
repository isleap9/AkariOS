# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Remove Recycle Bin Name": a per-user
# CLSID key whose name is a space. Windows has no such key, so Revert deletes it.
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}'
@{
    Id          = 'explorer-recycle-bin-no-name'
    Name        = 'Recycle Bin icon without its name'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'The Recycle Bin on the desktop shows only its icon, no "Recycle Bin" text under it.'
    Registry    = @(
        @{ Path = $k; Name = '(default)'; Type = 'String'; Value = ' '; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
