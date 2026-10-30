# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\AddEmptyRecycleBin.reg "Empty Recycle
# Bin": the Recycle Bin's own verb, put on the desktop menu. Windows has no such key, so Revert deletes it.
$k = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\EmptyRecycleBin'
@{
    Id          = 'context-add-empty-recycle-bin'
    Name        = 'Add Empty Recycle Bin to the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop shows Empty Recycle Bin (greyed out while it is empty).'
    Registry    = @(
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = '@shell32.dll,-10564'; Default = $null }
        @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = 'imageres.dll,-54'; Default = $null }
        @{ Path = $k; Name = 'CommandStateHandler'; Type = 'String'; Value = '{c9298eef-69dd-4cdd-b153-bdbc38486781}'; Default = $null }
        @{ Path = "$k\command"; Name = 'DelegateExecute'; Type = 'String'; Value = '{48527bb3-e8de-450b-8910-8c4099cb8624}'; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
