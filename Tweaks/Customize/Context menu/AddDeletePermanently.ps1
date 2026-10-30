# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\superdel.reg "Delete Permanently": a
# verb on every file (its second key, under *\shellex, is not a verb and does nothing; left out). Revert deletes it.
$k = 'HKLM:\SOFTWARE\Classes\*\shell\Delete Permanently'
@{
    Id          = 'context-add-delete-permanently'
    Name        = 'Add Delete Permanently to files'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Right-clicking a file shows Delete Permanently, which deletes it at once: no question, no Recycle Bin.'
    Registry    = @(
        @{ Path = "$k\command"; Name = '(default)'; Type = 'String'; Value = 'cmd.exe /c del /q /f "%1"'; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
