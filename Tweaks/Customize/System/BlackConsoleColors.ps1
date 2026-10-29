# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Black PowerShell console": the colours
# system-black-console doesn't set (its FaceName = Consolas is left out: Windows PowerShell's key already has it).
# Default: Windows PowerShell's own key holds ColorTable06 = its light grey text; the rest come from the console defaults.
@{
    Id          = 'system-black-console-colors'
    Name        = 'Pure black consoles'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Windows PowerShell and Command Prompt use pure black behind pure white text, instead of the near-black and grey of the console palette.'
    Registry    = @(
        @{ Path = 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe'; Name = 'ColorTable00'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe'; Name = 'ColorTable06'; Type = 'DWord'; Value = 0x00ffffff; Default = 0x00f0edee }
        @{ Path = 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe'; Name = 'ColorTable15'; Type = 'DWord'; Value = 0x00ffffff; Default = $null }
        @{ Path = 'HKCU:\Console\%SystemRoot%_system32_cmd.exe'; Name = 'ColorTable00'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Console\%SystemRoot%_system32_cmd.exe'; Name = 'ColorTable07'; Type = 'DWord'; Value = 0x00ffffff; Default = $null }
    )
}
