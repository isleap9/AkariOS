# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Enable last open window in taskbar".
@{
    Id          = 'taskbar-last-active-click'
    Name        = 'Click opens the last used window'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'Clicking an app with several windows on the taskbar switches straight to the one you used last, instead of showing the thumbnails.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'LastActiveClick'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
