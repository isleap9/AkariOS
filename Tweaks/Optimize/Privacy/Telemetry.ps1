# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'privacy-telemetry'
    Name        = 'Telemetry and feedback off'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Least diagnostic data (policy), no feedback prompts, no tailored experiences, no error reports, no app launch tracking.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'Disabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled'; Name = 'Value'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\EdgeUI'; Name = 'DisableMFUTracking'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI'; Name = 'DisableMFUTracking'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\Software\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules'; Name = 'NumberOfSIUFInPeriod'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
