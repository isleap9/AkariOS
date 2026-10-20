# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\8 Widgets and 1 Start Menu Taskbar (same policy).
@{
    Id          = 'taskbar-disable-widgets'
    Name        = 'Turn off Widgets'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Removes the Widgets button and board (news, weather) and stops them running in the background.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests'; Name = 'value'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
