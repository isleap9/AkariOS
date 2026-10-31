# The ISO Builder's always-on settings, from zoicware's zISO Tweaker (MIT, LICENSE-zISOTweaker.txt):
# ISOTweakerFuncs.psm1 Disable-W11Req and Disable-WindowsAnnoyances, and zISOTweaker.ps1's boot.wim step.
# Registry rows: Path starts with the image's hive (SOFTWARE, SYSTEM, NTUSER = the default user, DEFAULT); a row with
# no Name and Value = $null deletes the key; Value = $null with a Name deletes the value; Trusted = written as
# TrustedInstaller. Remove: paths under the mounted image (wildcards allowed).
@{
    # install.wim and boot.wim
    Requirements = @(
        @{ Path = 'DEFAULT\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV1'; Type = 'DWord'; Value = 0 }
        @{ Path = 'DEFAULT\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV2'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV1'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\Control Panel\UnsupportedHardwareNotificationCache'; Name = 'SV2'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassCPUCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassRAMCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassSecureBootCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassStorageCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\LabConfig'; Name = 'BypassTPMCheck'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\Setup\MoSetup'; Name = 'AllowUpgradesWithUnsupportedTPMOrCPU'; Type = 'DWord'; Value = 1 }
    )

    # boot.wim only
    Boot = @(
        @{ Path = 'SYSTEM\Setup\Status\ChildCompletion'; Name = 'setup.exe'; Type = 'DWord'; Value = 3 }
    )

    # install.wim
    Registry = @(
        # sponsored apps, content delivery
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'OemPreInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SilentInstalledAppsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'ContentDeliveryAllowed'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'FeatureManagementEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'PreInstalledAppsEverEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SoftLandingEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContentEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-310093Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338388Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338389Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-338393Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353694Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SubscribedContent-353696Enabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name = 'SystemPaneSuggestionsEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions'; Value = $null }
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SuggestedApps'; Value = $null }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableConsumerAccountStateContent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableCloudOptimizedContent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\PushToInstall'; Name = 'DisablePushToInstall'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\MRT'; Name = 'DontOfferThroughWUAU'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests'; Name = 'value'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'HubMode'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\EdgeUpdate'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\CrossDeviceUpdate'; Value = $null }
        # new Teams and Outlook
        @{ Path = 'SOFTWARE\Policies\Microsoft\Teams'; Name = 'DisableInstallation'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Windows Mail'; Name = 'PreventRun'; Type = 'DWord'; Value = 1 }
        # Windows Platform Binary Table, co-installers
        @{ Path = 'SYSTEM\ControlSet001\Control\Session Manager'; Name = 'DisableWpbtExecution'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer'; Name = 'DisableCoInstallers'; Type = 'DWord'; Value = 1 }
        # first logon animation
        @{ Path = 'SOFTWARE\Microsoft\Active Setup\Installed Components\CMP_NoFla'; Name = '(default)'; Type = 'String'; Value = 'Stop First Logon Animation Process' }
        @{ Path = 'SOFTWARE\Microsoft\Active Setup\Installed Components\CMP_NoFla'; Name = 'StubPath'; Type = 'ExpandString'; Value = '"%WINDIR%\System32\cmd.exe" /C "taskkill /f /im firstlogonanim.exe"' }
        # Cross Device Resume
        @{ Path = 'SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume'; Name = 'value'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1387020943'; Name = 'EnabledState'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1694661260'; Name = 'EnabledState'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Shell\ShellUIHosts\CrossDeviceResumeHost'; Name = 'ProcessPath'; Type = 'String'; Value = '%SystemRoot%\system32\ShellHost.exe'; Trusted = $true }
        # User Choice Protection Driver, AI Fabric, Windows Quality and Health Insights
        @{ Path = 'SYSTEM\ControlSet001\Services\UCPD'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\WSAIFabricSvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\whesvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\wuqisvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        # classic context menu for the first user who signs in
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Name = 'ClassicContext'; Type = 'String'; Value = 'reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /f' }
        # device region outside the regions that get Copilot and other cloud features (zISO: 68)
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion'; Name = 'DeviceRegion'; Type = 'DWord'; Value = 68 }
    )

    Remove = @(
        'Windows\System32\Tasks\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
        'Windows\System32\Tasks\Microsoft\Windows\Application Experience\ProgramDataUpdater'
        'Windows\System32\Tasks\Microsoft\Windows\Customer Experience Improvement Program'
        'Windows\InboxApps'
        'Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\CrossDeviceResume.exe'
        'Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\CrossDeviceResumeView.dll'
        'Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\CrossDeviceResume'
        'Windows\System32\UCPDMgr.exe'
        'Windows\System32\drivers\UCPD.sys'
        'Windows\System32\Tasks\Microsoft\Windows\AppxDeploymentClient\UCPD velocity'
        'Program Files (x86)\Internet Explorer'
        'Program Files\Internet Explorer'
        'Program Files (x86)\Windows Mail'
        'Program Files\Windows Mail'
    )
}
