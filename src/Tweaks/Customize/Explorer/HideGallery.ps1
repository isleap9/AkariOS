# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings. A per-user CLSID key that
# unpins it; Revert deletes the key again.
@{
    Id          = 'explorer-hide-gallery'
    Name        = 'Hide Gallery'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Removes Gallery from the File Explorer navigation pane.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; Name = 'System.IsPinnedToNameSpaceTree'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; Value = 'Key'; Default = $null }
    )
}
