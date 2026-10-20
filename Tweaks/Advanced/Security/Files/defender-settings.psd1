# Windows Security values of security-defender-settings: Value = AkariOS (One-click stepone.ps1 / FR33THY "Defender
# Optimize"), Default = FR33THY's "Defender Default". The SmartScreen values for Edge and Store apps are
# security-defender-tasks-off's (they need a normal boot).
@{
    Registry = @(
        # virus & threat protection: dev drive protection, cloud protection, sample submission, tamper protection
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableAsyncScanOnOpen'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet'; Name = 'SpyNetReporting'; Type = 'DWord'; Value = 0; Default = 2 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet'; Name = 'SubmitSamplesConsent'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features'; Name = 'TamperProtection'; Type = 'DWord'; Value = 4; Default = 5 }
        # ransomware protection: controlled folder access
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access'; Name = 'EnableControlledFolderAccess'; Type = 'DWord'; Value = 0; Default = 1 }
        # notifications
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications'; Name = 'DisableEnhancedNotifications'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender Security Center\Virus and threat protection'; Name = 'NoActionNotificationDisabled'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender Security Center\Virus and threat protection'; Name = 'SummaryNotificationDisabled'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender Security Center\Virus and threat protection'; Name = 'FilesBlockedNotificationDisabled'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows Defender Security Center\Account protection'; Name = 'DisableNotifications'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows Defender Security Center\Account protection'; Name = 'DisableDynamiclockNotifications'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows Defender Security Center\Account protection'; Name = 'DisableWindowsHelloNotifications'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Epoch'; Name = 'Epoch'; Type = 'DWord'; Value = 1231; Default = 1228 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile'; Name = 'DisableNotifications'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile'; Name = 'DisableNotifications'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile'; Name = 'DisableNotifications'; Type = 'DWord'; Value = 1; Default = 0 }
        # smart app control, potentially unwanted apps
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'; Name = 'VerifiedAndReputableTrustModeEnabled'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'; Name = 'SmartLockerMode'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'; Name = 'PUAProtection'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\AppID\Configuration\SMARTLOCKER'; Name = 'START_PENDING'; Type = 'DWord'; Value = 0; Default = 4 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\AppID\Configuration\SMARTLOCKER'; Name = 'ENABLED'; Type = 'Binary'; Value = @(0, 0, 0, 0, 0, 0, 0, 0); Default = @(4, 0, 0, 0, 0, 0, 0, 0) }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'VerifiedAndReputablePolicyState'; Type = 'DWord'; Value = 0; Default = 1 }
        # reputation-based protection: check apps and files, phishing protection
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'SmartScreenEnabled'; Type = 'String'; Value = 'Off'; Default = 'Warn' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'CaptureThreatWindow'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'NotifyMalicious'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'NotifyPasswordReuse'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'NotifyUnsafeApp'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'ServiceEnabled'; Type = 'DWord'; Value = 0; Default = 1 }
        # exploit protection (system-wide mitigations)
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'; Name = 'MitigationOptions'; Type = 'Binary'
           Value = @(0x22, 0x22, 0x22, 0, 0, 0x02, 0, 0, 0, 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
           Default = @(0x11, 0x11, 0x11, 0, 0, 0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) }
        # core isolation: memory integrity, LSA protection, vulnerable driver blocklist
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; Name = 'WasEnabledBy'; Type = 'DWord'; Value = $null; Default = 2 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RunAsPPL'; Type = 'DWord'; Value = 0; Default = 2 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config'; Name = 'VulnerableDriverBlocklistEnable'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
