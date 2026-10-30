# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable jump list when hovering inactive
# apps".
@{
    Id          = 'taskbar-no-jump-list-hover'
    Name        = 'No jump list on hover'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Hovering a pinned app that isn''t running no longer pops up its jump list; right-click still shows it.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'JumplistOnHover'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
