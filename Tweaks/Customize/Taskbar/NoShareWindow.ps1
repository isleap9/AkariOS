# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'taskbar-no-share-window'
    Name        = 'No "Share this window" on the taskbar'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Hides the Teams "Share this window" button when you hover a taskbar app.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarSn'; Type = 'DWord'; Value = 0; Default = $null }
}
