# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): Windows' consumer features
# off in the image, so suggested and sponsored apps never install for new users. Microsoft's documented policies
# (CloudContent, PushToInstall, Teams, Windows Mail) and the Content Delivery Manager values, as zISO Tweaker sets
# them (MIT, CREDITS.md). Rows: Path starts with the image's hive; a row with no Name and Value = $null deletes the key.
@{
    Name        = 'No sponsored apps'
    Description = 'Suggested and sponsored apps, new Teams and new Outlook don''t install themselves for new accounts.'
    Kind        = 'Settings'
    Risk        = 'Safe'
    Order       = 2
    Registry    = @(
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEverEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContentEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions'; Value = $null }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps'; Value = $null }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableConsumerAccountStateContent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableCloudOptimizedContent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\PushToInstall'; Name = 'DisablePushToInstall'; Type = 'DWord'; Value = 1 }
        # apps setup installs at the first sign-in through Windows Update's orchestrator
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate'; Value = $null }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Teams'; Name = 'DisableInstallation'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Windows Mail'; Name = 'PreventRun'; Type = 'DWord'; Value = 1 }
    )
}
