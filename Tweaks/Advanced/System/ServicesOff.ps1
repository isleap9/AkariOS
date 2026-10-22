# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\17 Services: "Services: Off", Revert = its "Services:
# Default". One Toggle over Files\services.psd1 (216 start types); per-service picks may come with Optimize > Advanced.
# Many service keys are protected: Safe Mode, TrustedInstaller (then as admin), like FR33THY's .reg import.
@{
    Id          = 'advanced-services-off'
    Name        = 'Turn off most Windows services'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Advanced'
    SafeMode    = $true
    Reboot      = $true
    Description = 'FR33THY''s "Services: Off": 216 services disabled or set to manual, among them Windows Update, Wi-Fi, Bluetooth, printing, file sharing, the firewall, the event log, Xbox and telemetry. Only for a dedicated gaming PC. Needs Safe Mode: Akari restarts into it and back.'
    Confirm     = 'This turns off most Windows services, including Windows Update, Wi-Fi, Bluetooth, printing, file sharing and the firewall. Things that need them stop working until you revert it. Select it anyway?'
    Detect      = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\services.psd1").Services |
            ForEach-Object { @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)"; Name = 'Start'; Type = 'DWord'; Value = $_.Off; Default = $_.Default } } |
            Where-Object { Test-Path -LiteralPath (Resolve-AkariRegPath $_.Path) })
        Get-AkariRegistryState $rows
    }
    Apply       = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\services.psd1").Services |
            ForEach-Object { @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)"; Name = 'Start'; Type = 'DWord'; Value = $_.Off; Default = $_.Default } } |
            Where-Object { Test-Path -LiteralPath (Resolve-AkariRegPath $_.Path) })
        Invoke-AkariRegistryTrusted $rows Apply
        foreach ($r in $rows) { try { Invoke-AkariRegistry @($r) Apply } catch { "Kept by Windows: $($r.Path) ($($_.Exception.Message))" } }
    }
    Revert      = {
        $rows = @((Import-PowerShellDataFile "$AkariTweakDir\Files\services.psd1").Services |
            ForEach-Object { @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)"; Name = 'Start'; Type = 'DWord'; Value = $_.Off; Default = $_.Default } } |
            Where-Object { Test-Path -LiteralPath (Resolve-AkariRegPath $_.Path) })
        Invoke-AkariRegistryTrusted $rows Revert
        foreach ($r in $rows) { try { Invoke-AkariRegistry @($r) Revert } catch { "Kept by Windows: $($r.Path) ($($_.Exception.Message))" } }
    }
}
