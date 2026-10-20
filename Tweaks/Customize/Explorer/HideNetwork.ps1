# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings. A per-user CLSID key that
# unpins it; Revert deletes the key again.
@{
    Id          = 'explorer-hide-network'
    Name        = 'Hide Network'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Removes Network from the File Explorer navigation pane. Network shares still open by address.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}'; Name = 'System.IsPinnedToNameSpaceTree'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}'; Value = 'Key'; Default = $null }
    )
}
