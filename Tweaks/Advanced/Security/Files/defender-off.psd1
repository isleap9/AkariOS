# Values of security-defender-off (FR33THY Ultimate 8 Advanced\1 Defender): Value = "Defender: Disable", Default =
# its "Defender: Enable (Default)". Only what the Windows Security settings and Defender tasks Tweaks don't own already.
# A service row whose key this Windows doesn't have (Windows 10 has no MDCoreSvc, webthreatdefsvc...) is skipped.
@{
    Registry = @(
        # real-time protection (security-defender-settings leaves it on)
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRealtimeMonitoring'; Type = 'DWord'; Value = 1; Default = 0 }
        # Defender services: network inspection, antivirus, core, Security Center, web threat defense (+ its user
        # service template), Defender for Endpoint, Windows Security
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 3 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 2 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\MDCoreSvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 2 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\wscsvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 2 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\webthreatdefsvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 3 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\webthreatdefusersvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 2 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Sense'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 3 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 2 }
        # Defender drivers: boot, mini-filter, network inspection
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\WdBoot'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 0 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 0 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\WdNisDrv'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 3 }
        # "Scan with Microsoft Defender" in the right-click menu (files, folders, drives)
        @{ Path = 'HKLM:\SOFTWARE\Classes\*\shellex\ContextMenuHandlers\EPP'; Name = '(default)'; Type = 'String'; Value = $null; Default = '{09A47860-11B0-4DA5-AFA5-26D86198A780}' }
        @{ Path = 'HKLM:\SOFTWARE\Classes\Directory\shellex\ContextMenuHandlers\EPP'; Name = '(default)'; Type = 'String'; Value = $null; Default = '{09A47860-11B0-4DA5-AFA5-26D86198A780}' }
        @{ Path = 'HKLM:\SOFTWARE\Classes\Drive\shellex\ContextMenuHandlers\EPP'; Name = '(default)'; Type = 'String'; Value = $null; Default = '{09A47860-11B0-4DA5-AFA5-26D86198A780}' }
        # the Windows Security tray icon at sign-in
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Name = 'SecurityHealth'; Type = 'ExpandString'; Value = $null; Default = '%windir%\system32\SecurityHealthSystray.exe' }
    )
}
