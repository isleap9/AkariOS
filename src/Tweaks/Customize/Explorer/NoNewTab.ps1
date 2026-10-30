# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable explorer open in new tab".
@{
    Id          = 'explorer-no-new-tab'
    Name        = 'Open folders in a new window, not a tab'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Folders opened from the desktop or from a link get their own File Explorer window instead of a new tab in the open one.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'OpenFolderInNewTab'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
