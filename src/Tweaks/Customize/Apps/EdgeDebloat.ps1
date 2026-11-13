# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksEdgeDebloat".
@{
    Id          = 'apps-edge-debloat'
    Name        = 'Microsoft Edge: no shopping, rewards, first run or tracking'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'For a kept Edge: group policies turn off the shopping assistant, Rewards, Collections, the first-run pages, recommendations, feedback and diagnostic data, and stop Edge Update adding a desktop shortcut.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'; Name = 'CreateDesktopShortcutDefault'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'PersonalizationReportingEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist'; Name = '1'; Type = 'String'; Value = 'ofefcgjbeghpigppfmkologfjadafddi'; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'ShowRecommendationsEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'HideFirstRunExperience'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'UserFeedbackAllowed'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'ConfigureDoNotTrack'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'AlternateErrorPagesEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeCollectionsEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeShoppingAssistantEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'MicrosoftEdgeInsiderPromotionEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'ShowMicrosoftRewards'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'WebWidgetAllowed'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'DiagnosticData'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeAssetDeliveryServiceEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'WalletDonationEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'DefaultBrowserSettingsCampaignEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
