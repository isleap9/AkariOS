# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-terminal-not-default'
    Name        = 'Console windows instead of Terminal'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Requires    = 'Win11'
    Description = 'Command Prompt and PowerShell open in the classic console window, not in Windows Terminal.'
    Registry    = @(
        @{ Path = 'HKCU:\Console\%%Startup'; Name = 'DelegationConsole'; Type = 'String'; Value = '{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}'; Default = $null }
        @{ Path = 'HKCU:\Console\%%Startup'; Name = 'DelegationTerminal'; Type = 'String'; Value = '{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}'; Default = $null }
    )
}
