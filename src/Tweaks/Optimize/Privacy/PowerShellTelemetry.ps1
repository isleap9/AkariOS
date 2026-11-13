# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksTelemetry"
# (its PowerShell 7 part; the rest is privacy-telemetry and defender-settings).
@{
    Id          = 'privacy-powershell-telemetry'
    Name        = 'PowerShell 7 telemetry off'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Sets POWERSHELL_TELEMETRY_OPTOUT for every user, so PowerShell 7 sends no usage data. Programs started afterwards see it.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'; Name = 'POWERSHELL_TELEMETRY_OPTOUT'; Type = 'String'; Value = '1'; Default = $null }
    )
}
