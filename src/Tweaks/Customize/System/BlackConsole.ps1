# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-black-console'
    Name        = 'Black PowerShell console'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows PowerShell opens black instead of blue.'
    Registry    = @(
        @{ Path = 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe'; Name = 'ScreenColors'; Type = 'DWord'; Value = 15; Default = 86 }
    )
}
