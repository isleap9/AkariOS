# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Enable Windows 10 File Explorer": two
# per-user CLSID keys point the new Explorer's view at a missing DLL (the trailing "_"), so it falls back to the ribbon.
# Its ITBar7Layout blob and the ribbon's minimized state are not ported (Explorer writes them; no Default). Revert
# deletes the keys.
$c = 'HKCU:\Software\Classes\CLSID'
$dll = 'C:\Windows\System32\Windows.UI.FileExplorer.dll_'
@{
    Id          = 'explorer-windows10-ribbon'
    Name        = 'Windows 10 File Explorer (ribbon)'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Caution'
    Requires    = 'Win11'
    Guided      = $false
    Explorer    = $true
    Description = 'File Explorer opens with Windows 10''s ribbon and toolbar instead of the Windows 11 command bar and tabs. A Windows update may stop it working.'
    Registry    = @(
        foreach ($g in @(@('{2aa9162e-c906-4dd9-ad0b-3d24a8eef5a0}', 'CLSID_ItemsViewAdapter'), @('{6480100b-5a83-4d1e-9f69-8ae5a88e9a33}', 'File Explorer Xaml Island View Adapter'))) {
            @{ Path = "$c\$($g[0])"; Name = '(default)'; Type = 'String'; Value = $g[1]; Default = $null }
            @{ Path = "$c\$($g[0])\InProcServer32"; Name = '(default)'; Type = 'String'; Value = $dll; Default = $null }
            @{ Path = "$c\$($g[0])\InProcServer32"; Name = 'ThreadingModel'; Type = 'String'; Value = 'Apartment'; Default = $null }
            @{ Path = "$c\$($g[0])"; Value = 'Key'; Default = $null }
        }
    )
}
