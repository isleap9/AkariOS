# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\4 Context Menu. The per-user CLSID key overrides the
# new menu's handler; Revert deletes it again (an empty key left behind would keep the classic menu).
@{
    Id          = 'explorer-classic-context-menu'
    Name        = 'Classic right-click menu'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Right-click shows the full Windows 10 menu at once, without "Show more options".'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; Name = '(default)'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'; Value = 'Key'; Default = $null }
    )
}
