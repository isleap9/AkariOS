# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Disable-Telemetry (its commented-out lines left out).
@{
    Name        = 'Disable telemetry'
    Description = 'Diagnostic data off, its services off, no advertising ID, activity history, clipboard sync, typing and inking data or app compatibility tracking.'
    Group       = 'Security'
    Order       = 4
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'DisableGraphRecentItems'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowClipboardHistory'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'AllowCrossDeviceClipboard'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'; Name = 'DontSendAdditionalData'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowDeviceNameInTelemetry'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableCloudOptimizedContent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'MaxTelemetryAllowed'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SYSTEM\ControlSet001\Services\DiagTrack'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\dmwappushservice'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Biometrics'; Name = 'Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\AppV\CEIP'; Name = 'CEIPEnable'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Name = 'CEIPEnable'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\DevicePolicy\AllowTelemetry'; Name = 'DefaultValue'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\AllowTelemetry'; Name = 'Value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowCommercialDataPipeline'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'LimitEnhancedDiagnosticDataWindowsAnalytics'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableTailoredExperiencesWithDiagnosticData'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Personalization\Settings'; Name = 'AcceptedPrivacyPolicy'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\current\device\Bluetooth'; Name = 'AllowAdvertising'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\current\device\System'; Name = 'AllowExperimentation'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Wifi\AllowAutoConnectToWiFiSenseHotspots'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Wifi\AllowWiFiHotSpotReporting'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\WMDRM'; Name = 'DisableOnline'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'AITEnable'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisableInventory'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisablePCA'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisablePcaRecording'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisableScriptedDiagnosticLogging'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name = 'DisableUAR'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\ControlSet001\Control\StorPort'; Name = 'TelemetryDeviceHealthEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SYSTEM\ControlSet001\Control\StorPort'; Name = 'TelemetryErrorDataEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SYSTEM\ControlSet001\Control\StorPort'; Name = 'TelemetryPerformanceEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SYSTEM\ControlSet001\Services\whesvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\wuqisvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'NTUSER\Software\Microsoft\Input\TIPC'; Name = 'Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore'; Name = 'HarvestContacts'; Type = 'DWord'; Value = 0 }
    )
}
