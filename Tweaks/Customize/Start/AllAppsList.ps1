# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar and 2 Start Menu Layout.
@{
    Id          = 'start-all-apps-list'
    Name        = 'All apps as a list'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'All apps in the new Start menu shows a plain A to Z list instead of categories.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'AllAppsViewMode'; Type = 'DWord'; Value = 2; Default = 0 }
}
