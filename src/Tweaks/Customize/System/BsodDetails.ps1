# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-bsod-details'
    Name        = 'Details on blue screens'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'A blue screen shows the technical error details.'
    Registry    = @(
        @{ Path = 'HKLM:\System\CurrentControlSet\Control\CrashControl'; Name = 'DisplayParameters'; Type = 'DWord'; Value = 1; Default = 0 }
    )
}
