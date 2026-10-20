# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'start-hide-recent-items'
    Name        = 'Hide recent files'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'No recently opened files in Start, in jump lists, or in File Explorer.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackDocs'; Type = 'DWord'; Value = 0; Default = $null }
}
