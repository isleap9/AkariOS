# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar.
@{
    Id          = 'taskbar-disable-news-interests'
    Name        = 'Turn off News and interests'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win10'
    Explorer    = $true
    Description = 'Removes the weather and news panel from the taskbar.'
    Registry    = @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'; Name = 'EnableFeeds'; Type = 'DWord'; Value = 0; Default = $null }
}
