# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Strip-WinAI, without its RemoveWindowsAI .cab and the zoicware root certificate it adds to the image for it
# (plan: no third-party root certificate in the image). Its servicing\Packages and CatRoot matches are left out too:
# zISO looks for folders there and finds none (they hold files), and removing package manifests breaks servicing.
@{
    Name        = 'Remove Windows AI'
    Description = 'Copilot, Recall, Click to Do and the AI apps removed; AI policies set in Windows, Edge and Paint.'
    Group       = 'Apps'
    Order       = 3
    Features    = @('Recall')
    # provisioned apps (removed with DISM when the image has them)
    Apps        = @('Microsoft.Copilot', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.Office.ActionsServer', 'Microsoft.WritingAssistant', 'Microsoft.Edge.GameAssist', 'aimgr')
    # registry keys whose last part is a wildcard
    RemoveKeys  = @(
        'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications\MicrosoftWindows.Client.CoreAI*'
    )
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'AllowRecallEnablement'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'TurnOffSavingSnapshots'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableSettingsAgent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat'; Name = 'IsUserEligible'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\Shell\Copilot'; Name = 'IsCopilotAvailable'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\Shell\Copilot'; Name = 'CopilotDisabledReason'; Type = 'String'; Value = 'FeatureIsDisabled' }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'CopilotCDPPageContext'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'CopilotPageContext'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'HubsSidebarEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeEntraCopilotPageContext'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'Microsoft365CopilotChatIconEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeHistoryAISearchEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'ComposeInlineEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'GenAILocalFoundationalModelSettings'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'; Name = 'AutoOpenCopilotLargeScreens'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\generativeAI'; Name = 'Value'; Type = 'String'; Value = 'Deny' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels'; Name = 'Value'; Type = 'String'; Value = 'Deny' }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessGenerativeAI'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessSystemAIModels'; Type = 'DWord'; Value = 2 }
        # zISO: keeps Explorer from depending on the AI Fabric service
        @{ Path = 'SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1561856655'; Name = 'EnabledState'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\940684430'; Name = 'EnabledState'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableImageCreator'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableCocreator'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableGenerativeFill'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableGenerativeErase'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableRemoveBackground'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\ControlSet001\Services\WSAIFabricSvc'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Shell\Update\Packages\Components'; Name = 'AIX'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Shell\Update\Packages\Components'; Name = 'CopilotNudges'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Shell\Update\Packages\Components'; Name = 'AIContext'; Value = $null }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'SettingsPageVisibility'; Type = 'String'; Value = 'hide:aicomponents;' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Config\MicrosoftWindows.Client.CoreAI_cw5n1h2txyewy'; Value = $null }
        # deprovisioned: Windows won't install them for new users
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\MicrosoftWindows.Client.CoreAI_cw5n1h2txyewy'; Value = 'Key' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.Copilot_8wekyb3d8bbwe'; Value = 'Key' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe'; Value = 'Key' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.Office.ActionsServer_8wekyb3d8bbwe'; Value = 'Key' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\aimgr_8wekyb3d8bbwe'; Value = 'Key' }
    )
    Remove      = @(
        # the AI packages' folders (zISO's $aipackages, in SystemApps, WindowsApps, AppRepository and SystemApps\SxS)
        'Windows\SystemApps\*MicrosoftWindows.Client.AIX*'
        'Windows\SystemApps\*MicrosoftWindows.Client.CoPilot*'
        'Windows\SystemApps\*Microsoft.Windows.Ai.Copilot.Provider*'
        'Windows\SystemApps\*MicrosoftWindows.Client.CoreAI*'
        'Windows\SystemApps\*Microsoft.AIFabric.CBS*'
        'Windows\SystemApps\SxS\*MicrosoftWindows.Client.AIX*'
        'Windows\SystemApps\SxS\*MicrosoftWindows.Client.CoPilot*'
        'Windows\SystemApps\SxS\*MicrosoftWindows.Client.CoreAI*'
        'Windows\SystemApps\SxS\*Microsoft.AIFabric.CBS*'
        'Program Files\WindowsApps\*MicrosoftWindows.Client.AIX*'
        'Program Files\WindowsApps\*MicrosoftWindows.Client.CoPilot*'
        'Program Files\WindowsApps\*Microsoft.Windows.Ai.Copilot.Provider*'
        'Program Files\WindowsApps\*Microsoft.Copilot*'
        'Program Files\WindowsApps\*Microsoft.MicrosoftOfficeHub*'
        'Program Files\WindowsApps\*MicrosoftWindows.Client.CoreAI*'
        'Program Files\WindowsApps\*Microsoft.Edge.GameAssist*'
        'Program Files\WindowsApps\*Microsoft.Office.ActionsServer*'
        'Program Files\WindowsApps\*aimgr*'
        'Program Files\WindowsApps\*Microsoft.WritingAssistant*'
        'Program Files\WindowsApps\*Microsoft.AIFabric.CBS*'
        'Program Files\WindowsApps\*WindowsWorkload*'
        'Program Files\WindowsApps\*Voiess*'
        'Program Files\WindowsApps\*Speion*'
        'Program Files\WindowsApps\*Livtop*'
        'Program Files\WindowsApps\*InpApp*'
        'Program Files\WindowsApps\*Filons*'
        'ProgramData\Microsoft\Windows\AppRepository\Packages\*MicrosoftWindows.Client.AIX*'
        'ProgramData\Microsoft\Windows\AppRepository\Packages\*MicrosoftWindows.Client.CoPilot*'
        'ProgramData\Microsoft\Windows\AppRepository\Packages\*MicrosoftWindows.Client.CoreAI*'
        'ProgramData\Microsoft\Windows\AppRepository\Packages\*Microsoft.Copilot*'
        # machine learning and the Settings AI pages
        'Windows\System32\Windows.AI.MachineLearning.dll'
        'Windows\SysWOW64\Windows.AI.MachineLearning.dll'
        'Windows\System32\Windows.AI.MachineLearning.Preview.dll'
        'Windows\SysWOW64\Windows.AI.MachineLearning.Preview.dll'
        'Windows\System32\SettingsHandlers_Copilot.dll'
        'Windows\System32\SettingsHandlers_A9.dll'
        # Edge's installers of the Copilot provider
        'Program Files (x86)\Microsoft\Edge\Application\*.*.*.*\copilot_provider_msix'
        'Program Files (x86)\Microsoft\EdgeCore\*.*.*.*\copilot_provider_msix'
        'Program Files (x86)\Microsoft\EdgeWebView\Application\*.*.*.*\copilot_provider_msix'
        'Windows\System32\Tasks\Microsoft\Windows\WindowsAI'
    )
}
