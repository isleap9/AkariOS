# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-default-printer'
    Name        = 'Windows doesn''t pick the default printer'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The default printer stays the one you chose, not the last one used.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows'; Name = 'LegacyDefaultPrinterMode'; Type = 'DWord'; Value = 1; Default = 4294967295 }
    )
}
