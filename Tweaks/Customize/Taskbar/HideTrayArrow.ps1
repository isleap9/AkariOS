# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Show all taskbar icons": the chevron value.
# Its EnableAutoTray value belongs to taskbar-show-all-tray-icons.
@{
    Id          = 'taskbar-hide-tray-arrow'
    Name        = 'Hide the hidden-icons arrow'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Removes the ^ arrow next to the clock. Icons left in the overflow menu can then only be reached from Settings: pair it with Show all tray icons.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify'; Name = 'SystemTrayChevronVisibility'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
