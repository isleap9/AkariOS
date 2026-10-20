# Ported from AkariOS-Ultimate (FR33THY Ultimate) 7 Hardware\2 Background Polling Rate Cap.
@{
    Id          = 'input-background-polling-uncapped'
    Name        = 'No mouse polling cap in background windows'
    Section     = 'Hardware'
    Category    = 'Input'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows 11 caps raw mouse input to 125 Hz for windows in the background; this lifts the cap.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Mouse'; Name = 'RawMouseThrottleEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
