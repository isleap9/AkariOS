# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings (FR33THY's compact Start;
# AkariOS keeps the pins, so this is not part of the AkariOS setup).
@{
    Id          = 'start-hide-pinned-section'
    Name        = 'Hide the pinned section in Start'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'The new Start menu shows only All apps, no pinned apps on top.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowPinnedSection'; Type = 'DWord'; Value = 0; Default = $null }
}
