# ISO Builder removal group, ported from Tiny11 Builder (ntdevlabs, used with its developers' permission: ADR 0010,
# docs/permissions/tiny11builder.md) at commit 38f7ab6b1f177098c026a19b73ec84bca9c4b874: src/Tiny11Builder.Core/PolicyCatalog.cs
# ("ads", "privacy", "copilot", "widgets", "search", "onedrive", "edge", "oobe"): HKLM = SOFTWARE, the default
# user = NTUSER. Rows: Path starts with the image's hive.
@{
    Name        = 'Ads, privacy, Copilot and Widgets (Tiny11)'
    Description = 'No sponsored apps or suggestions, required diagnostics only, no advertising ID, Copilot, Widgets, web search or setup nags. Each stays changeable in Settings.'
    Kind        = 'Settings'
    Risk        = 'Safe'
    Order       = 2
    Registry    = @(
        # ads
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableConsumerAccountStateContent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableCloudOptimizedContent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsSpotlightFeatures'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableThirdPartySuggestions'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableTailoredExperiencesWithDiagnosticData'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SoftLandingEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContentEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338393Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353696Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowSyncProviderNotifications'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\PushToInstall'; Name = 'DisablePushToInstall'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Teams'; Name = 'DisableInstallation'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Windows Mail'; Name = 'PreventRun'; Type = 'DWord'; Value = 1 }
        # privacy (required diagnostics stay on)
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'; Name = 'HasAccepted'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Input\TIPC'; Name = 'Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitInkCollection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\InputPersonalization'; Name = 'RestrictImplicitTextCollection'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\InputPersonalization\TrainedDataStore'; Name = 'HarvestContacts'; Type = 'DWord'; Value = 0 }
        # copilot
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowCopilotButton'; Type = 'DWord'; Value = 0 }
        # widgets and search
        @{ Path = 'SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'AllowCloudSearch'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name = 'EnableDynamicContentInWSB'; Type = 'DWord'; Value = 0 }
        # onedrive and edge
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name = 'DisableFileSyncNGSC'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'HideFirstRunExperience'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'HubsSidebarEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'ShowRecommendationsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'UserFeedbackAllowed'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'SpotlightExperiencesAndRecommendationsEnabled'; Type = 'DWord'; Value = 0 }
        # setup nags
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\OOBE'; Name = 'DisablePrivacyExperience'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name = 'ScoobeSystemSettingEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarMn'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Windows Chat'; Name = 'ChatIcon'; Type = 'DWord'; Value = 3 }
    )
}
