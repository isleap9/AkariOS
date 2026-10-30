# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings: "remove resume from taskbar"
# (the "Resume" suggestion to continue on this PC what you started on your phone).
@{
    Id          = 'taskbar-hide-resume'
    Name        = 'No Resume suggestions on the taskbar'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'The taskbar no longer offers to resume on this PC what you were doing on your phone.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'IsEnabled'; Type = 'DWord'; Value = 0; Default = $null }
}
