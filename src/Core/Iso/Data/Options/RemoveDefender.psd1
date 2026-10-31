# ISO Builder option "Remove Windows Defender", from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt):
# ISOTweakerFuncs.psm1 remove-Defender (features, the Security app, files) and Disable-Defender (its 11
# DisableDefenderRegistry\*.reg files, here as rows). Row format: ..\Always.psd1.
@{
    Name        = 'Remove Windows Defender'
    Description = 'Removes Defender''s features, the Windows Security app and Defender''s files, and turns off what is left of it, SmartScreen included.'
    Group       = 'Security'
    Order       = 1
    Features    = @('*Defender*')
    Apps        = @('Microsoft.SecHealthUI')
    Remove      = @(
        'Program Files\Windows Defender'
        'Program Files (x86)\Windows Defender'
        'Program Files\Windows Defender Advanced Threat Protection'
        'ProgramData\Microsoft\Windows Defender'
        'ProgramData\Microsoft\Windows Defender Advanced Threat Protection'
        'Windows\System32\SecurityHealth*'
        'Windows\System32\SecurityCenter*'
        'Windows\System32\smartscreen.exe'
        'Program Files\WindowsApps\Microsoft.SecHealthUI_*'
    )
    Registry    = @(
        # disable1.reg
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableRoutinelyTakingAction'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'ServiceKeepAlive'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'AllowFastServiceStartup'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableLocalAdminMerge'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableOnAccessProtection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideRealtimeScanDirection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableIOAVProtection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableBehaviorMonitoring'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableIntrusionPreventionSystem'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableRealtimeMonitoring'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableIOAVProtection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRealtimeMonitoring'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableBehaviorMonitoring'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableOnAccessProtection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableScanOnRealtimeEnable'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'RealtimeScanDirection'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableInformationProtectionControl'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableIntrusionPreventionSystem'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRawWriteNotification'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowBehaviorMonitoring'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\WOW6432Node\Policies\Microsoft\Windows Defender'; Name = 'DisableRoutinelyTakingAction'; Type = 'DWord'; Value = 1 }
        # disable2.reg
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIOAVProtection'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'PUAProtection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableRoutinelyTakingAction'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'ServiceKeepAlive'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'AllowFastServiceStartup'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableLocalAdminMerge'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableAntiSpyware'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'RandomizeScheduleTaskTimes'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowArchiveScanning'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowBehaviorMonitoring'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowCloudProtection'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowEmailScanning'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowFullScanOnMappedNetworkDrives'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowFullScanRemovableDriveScanning'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowIntrusionPreventionSystem'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowOnAccessProtection'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowRealtimeMonitoring'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowScanningNetworkFiles'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowScriptScanning'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowUserUIAccess'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\CheckForSignaturesBeforeRunningScan'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\CloudBlockLevel'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\CloudExtendedTimeout'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\DaysToRetainCleanedMalware'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\DisableCatchupFullScan'; Name = 'value'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\DisableCatchupQuickScan'; Name = 'value'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\EnableControlledFolderAccess'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\EnableLowCPUPriority'; Name = 'value'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\EnableNetworkProtection'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\PUAProtection'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\RealTimeScanDirection'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\ScanParameter'; Name = 'value'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\ScheduleScanDay'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\ScheduleScanTime'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\SignatureUpdateInterval'; Name = 'value'; Type = 'DWord'; Value = 24 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Defender\SubmitSamplesConsent'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions'; Name = 'DisableAutoExclusions'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine'; Name = 'MpEnablePus'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine'; Name = 'MpCloudBlockLevel'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine'; Name = 'MpBafsExtendedTimeout'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine'; Name = 'EnableFileHashComputation'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\NIS\Consumers\IPS'; Name = 'ThrottleDetectionEventsRate'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\NIS\Consumers\IPS'; Name = 'DisableSignatureRetirement'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\NIS\Consumers\IPS'; Name = 'DisableProtocolRecognition'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager'; Name = 'DisableScanningNetworkFiles'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRealtimeMonitoring'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableBehaviorMonitoring'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableOnAccessProtection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableScanOnRealtimeEnable'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableIOAVProtection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableOnAccessProtection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideRealtimeScanDirection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableIOAVProtection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableBehaviorMonitoring'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableIntrusionPreventionSystem'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'LocalSettingOverrideDisableRealtimeMonitoring'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'RealtimeScanDirection'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'IOAVMaxSize'; Type = 'DWord'; Value = 1298 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableInformationProtectionControl'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableIntrusionPreventionSystem'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRawWriteNotification'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'LowCpuPriority'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableRestorePoint'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableArchiveScanning'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableScanningNetworkFiles'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableCatchupFullScan'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableCatchupQuickScan'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableEmailScanning'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableHeuristics'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableReparsePointScanning'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'SignatureDisableNotification'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'RealtimeSignatureDelivery'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'ForceUpdateFromMU'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'DisableScheduledSignatureUpdateOnBattery'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'UpdateOnStartUp'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'SignatureUpdateCatchupInterval'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'DisableUpdateOnStartupWithoutEngine'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'ScheduleTime'; Type = 'DWord'; Value = 5184 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'DisableScanOnUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name = 'DisableBlockAtFirstSeen'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name = 'LocalSettingOverrideSpynetReporting'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name = 'SpynetReporting'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'; Name = 'SubmitSamplesConsent'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\UX Configuration'; Name = 'SuppressRebootNotification'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access'; Name = 'EnableControlledFolderAccess'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection'; Name = 'EnableNetworkProtection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\WOW6432Node\Policies\Microsoft\Windows Defender'; Name = 'DisableRoutinelyTakingAction'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Microsoft Antimalware'; Name = 'ServiceKeepAlive'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Microsoft Antimalware'; Name = 'AllowFastServiceStartup'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Microsoft Antimalware'; Name = 'DisableRoutinelyTakingAction'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Microsoft Antimalware'; Name = 'DisableAntiSpyware'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Microsoft Antimalware'; Name = 'DisableAntiVirus'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Microsoft Antimalware\SpyNet'; Name = 'SpyNetReporting'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Microsoft Antimalware\SpyNet'; Name = 'LocalSettingOverrideSpyNetReporting'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Reporting'; Name = 'DisableEnhancedNotifications'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Reporting'; Name = 'DisableGenericRePorts'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Reporting'; Name = 'WppTracingLevel'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Reporting'; Name = 'WppTracingComponents'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SYSTEM\ControlSet001\Control\CI\Policy'; Name = 'VerifiedAndReputablePolicyState'; Type = 'DWord'; Value = 0 }
        # disable3.reg
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\WindowsDefenderSecurityCenter\DisableEnhancedNotifications'; Name = 'value'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\WindowsDefenderSecurityCenter\DisableNotifications'; Name = 'value'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\WindowsDefenderSecurityCenter\HideWindowsSecurityNotificationAreaControl'; Name = 'value'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Security Center'; Name = 'FirstRunDisabled'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Security Center'; Name = 'AntiVirusOverride'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Security Center'; Name = 'FirewallOverride'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'; Name = 'DisableEnhancedNotifications'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'; Name = 'DisableNotifications'; Type = 'DWord'; Value = 1 }
        # disable5.reg
        @{ Path = 'SOFTWARE\Classes\WOW6432Node\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{2781761E-28E2-4109-99FE-B9D127C57AFE}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{195B4D07-3DE2-4744-BBF2-D90121AE785B}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{361290c0-cb1b-49ae-9f3e-ba1cbe5dab35}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{45F2C32F-ED16-4C94-8493-D72EF93A051B}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{6CED0DAA-4CDE-49C9-BA3A-AE163DC3D7AF}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{8a696d12-576b-422e-9712-01b9dd84b446}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{8C9C0DB7-2CBA-40F1-AFE0-C55740DD91A0}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{A2D75874-6750-4931-94C1-C99D3BC9D0C7}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{A7C452EF-8E9F-42EB-9F2B-245613CA0DC9}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{DACA056E-216A-4FD1-84A6-C306A017ECEC}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{E3C9166D-1D39-4D4E-A45D-BC7BE9B00578}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{F6976CF5-68A8-436C-975A-40BE53616D59}'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Control\WMI\Autologger\DefenderAuditLogger'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Control\WMI\Autologger\DefenderApiLogger'; Value = $null }
        # disable6.reg
        @{ Path = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{0ACC9108-2000-46C0-8407-5FD9F89521E8}'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{1D77BCC8-1D07-42D0-8C89-3A98674DFB6F}'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{4A9233DB-A7D3-45D6-B476-8C7D8DF73EB5}'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{B05F34EE-83F2-413D-BC1D-7D5BD6E98300}'; Value = $null }
        # disable7.reg
        @{ Path = 'SYSTEM\ControlSet001\Services\MsSecCore'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\wscsvc'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\WdNisDrv'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\WdNisSvc'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\WdFilter'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\WdBoot'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\webthreatdefusersvc'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\webthreatdefsvc'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SecurityHealthService'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SgrmAgent'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SgrmBroker'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\WinDefend'; Value = $null }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection'; Name = 'DisallowExploitProtectionOverride'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\ControlSet001\Services\MsSecFlt'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\MsSecWfp'; Value = $null }
        # disable8.reg
        @{ Path = 'SYSTEM\ControlSet001\Services\WinDefend'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\AppUserModelId\Windows.Defender'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\AppUserModelId\Microsoft.Windows.Defender'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\WindowsDefender'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Control\Ubpm'; Name = 'CriticalMaintenance_DefenderCleanup'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Control\Ubpm'; Name = 'CriticalMaintenance_DefenderVerification'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Control\Ubpm'; Name = 'CriticalMaintenance_DefenderCleanup'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Control\Ubpm'; Name = 'CriticalMaintenance_DefenderVerification'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'; Name = 'WindowsDefender-1'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'; Name = 'WindowsDefender-2'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'; Name = 'WindowsDefender-3'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'; Name = 'WindowsDefender-1'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'; Name = 'WindowsDefender-2'; Value = $null }
        @{ Path = 'SYSTEM\ControlSet001\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'; Name = 'WindowsDefender-3'; Value = $null }
        # disable9.reg
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'SignatureDisableNotification'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'RealtimeSignatureDelivery'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'ForceUpdateFromMU'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'DisableScheduledSignatureUpdateOnBattery'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'UpdateOnStartUp'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'SignatureUpdateCatchupInterval'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'DisableUpdateOnStartupWithoutEngine'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'ScheduleTime'; Type = 'DWord'; Value = 5184 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'DisableScanOnUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableSmartScreen'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen'; Name = 'ConfigureAppInstallControlEnabled'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen'; Name = 'ConfigureAppInstallControl'; Type = 'String'; Value = 'Anywhere' }
        # disable10.reg
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'Windows Defender'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'SecurityHealth'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Name = 'WindowsDefender'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Name = 'SecurityHealth'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\exefile\shell\open'; Name = 'NoSmartScreen'; Type = 'String'; Value = '' }
        @{ Path = 'SOFTWARE\Classes\exefile\shell\runas'; Name = 'NoSmartScreen'; Type = 'String'; Value = '' }
        @{ Path = 'SOFTWARE\Classes\exefile\shell\runasuser'; Name = 'NoSmartScreen'; Type = 'String'; Value = '' }
        @{ Path = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SmartScreen.exe'; Name = 'Debugger'; Type = 'String'; Value = 'systray.exe' }
        # disable11.reg
        @{ Path = 'SOFTWARE\Classes\CLSID\{a463fcb9-6b1c-4e0d-a80b-a2ca7999e25d}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\WOW6432Node\CLSID\{a463fcb9-6b1c-4e0d-a80b-a2ca7999e25d}'; Value = $null }
        @{ Path = 'SOFTWARE\WOW6432Node\Classes\CLSID\{a463fcb9-6b1c-4e0d-a80b-a2ca7999e25d}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{E48B2549-D510-4A76-8A5F-FC126A6215F0}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\WOW6432Node\CLSID\{E48B2549-D510-4A76-8A5F-FC126A6215F0}'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.Service.UserSessionServiceManager'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.ThreatExperienceManager.ThreatExperienceManager'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.ThreatResponseEngine.ThreatDecisionEngine'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Microsoft.OneCore.WebThreatDefense.Configuration.WTDUserSettings'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\CLSID\{a463fcb9-6b1c-4e0d-a80b-a2ca7999e25d}'; Value = $null }
        @{ Path = 'SOFTWARE\Classes\WOW6432Node\CLSID\{a463fcb9-6b1c-4e0d-a80b-a2ca7999e25d}'; Value = $null }
        @{ Path = 'SOFTWARE\WOW6432Node\Classes\CLSID\{a463fcb9-6b1c-4e0d-a80b-a2ca7999e25d}'; Value = $null }
        # disable12.reg
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender Security Center\Systray'; Name = 'HideSystray'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender\Features'; Name = 'TamperProtection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender\Features'; Name = 'TamperProtectionSource'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender\Signature Updates'; Name = 'FirstAuGracePeriod'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender\UX Configuration'; Name = 'DisablePrivacyMode'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\MRT'; Name = 'DontOfferThroughWUAU'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\MRT'; Name = 'DontReportInfectionInformation'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRoutinelyTakingAction'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableScriptScanning'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableRemovableDriveScanning'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'DisableScanningMappedNetworkDrivesForFullScan'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'ScanParameters'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'ScheduleDay'; Type = 'DWord'; Value = 8 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Scan'; Name = 'ScheduleTime'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'ScheduleDay'; Type = 'DWord'; Value = 8 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates'; Name = 'ScheduleTime'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SYSTEM\ControlSet001\Services\Microsoft-Antimalware-ShieldProvider'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\Sense'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'; Name = 'EnableWebContentEvaluation'; Type = 'DWord'; Value = 0 }
        @{ Path = 'DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'; Name = 'PreventOverride'; Type = 'DWord'; Value = 0 }
        @{ Path = 'DEFAULT\SOFTWARE\Policies\Microsoft\Edge'; Name = 'SmartScreenEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'; Name = 'EnableWebContentEvaluation'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'; Name = 'PreventOverride'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Policies\Microsoft\Edge'; Name = 'SmartScreenEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Security Health\State'; Name = 'AppAndBrowser_StoreAppsSmartScreenOff'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'; Name = 'SmartScreenEnabled'; Type = 'String'; Value = 'Off' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'SmartScreenEnabled'; Type = 'String'; Value = 'Off' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'CaptureThreatWindow'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'NotifyMalicious'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'NotifyPasswordReuse'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'NotifyUnsafeApp'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components'; Name = 'ServiceEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender'; Name = 'VerifiedAndReputableTrustModeEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender'; Name = 'SmartLockerMode'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access'; Name = 'EnableControlledFolderAccess'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Edge\SmartScreenEnabled'; Name = '(default)'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Edge\SmartScreenPuaEnabled'; Name = '(default)'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'SettingsPageVisibility'; Type = 'String'; Value = 'hide:windowsdefender;' }
    )
}
