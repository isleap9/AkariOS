# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings ("remove quick access").
@{
    Id          = 'explorer-hide-home'
    Name        = 'Hide Home / Quick access'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Removes Home (Quick access on Windows 10) from the File Explorer navigation pane. Pair it with Open File Explorer to This PC.'
    Registry    = @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'HubMode'; Type = 'DWord'; Value = 1; Default = $null }
}
