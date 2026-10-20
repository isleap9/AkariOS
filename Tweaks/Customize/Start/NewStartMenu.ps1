# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\2 Start Menu Layout (25H2 option): turns on the
# redesigned Start menu Microsoft rolls out in stages, through its feature overrides.
@{
    Id          = 'start-new-menu'
    Name        = 'New Start menu'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Caution'
    AkariOS     = $true
    Requires    = 'Win11'
    Reboot      = $true
    Description = 'The redesigned Start menu (one scrolling page, All apps below the pins) on builds that have it but hide it. Needs a recent Windows 11 build.'
    Registry    = @(
        foreach ($f in '2792562829', '3036241548', '734731404', '762256525') {
            @{ Path = "HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\14\$f"; Name = 'EnabledState'; Type = 'DWord'; Value = 2; Default = $null }
        }
    )
}
