# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): Windows AI out of the image,
# update-safe: the AI Store apps and the Recall feature removed, Microsoft's documented AI policies set, the AI apps
# deprovisioned. Unlike zISO Tweaker's Remove Windows AI (MIT, CREDITS.md), no system files or SystemApps folders are
# deleted, so servicing and cumulative updates keep working.
@{
    Name        = 'Windows AI'
    Description = 'Copilot, Recall, Click to Do and the AI apps removed or turned off by policy. System files stay, so updates still install.'
    Kind        = 'Apps'
    Risk        = 'Safe'
    Order       = 7
    Features    = @('Recall')
    Apps        = @('Microsoft.Copilot', 'Microsoft.Windows.AIHub', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.Office.ActionsServer', 'Microsoft.WritingAssistant', 'Microsoft.Edge.GameAssist', 'aimgr')
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Type = 'DWord'; Value = 1 }
        @{ Path = 'NTUSER\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'AllowRecallEnablement'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableClickToDo'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'TurnOffSavingSnapshots'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableSettingsAgent'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'CopilotPageContext'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'HubsSidebarEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Edge'; Name = 'Microsoft365CopilotChatIconEnabled'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessGenerativeAI'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessSystemAIModels'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableImageCreator'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableCocreator'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableGenerativeFill'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableGenerativeErase'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name = 'DisableRemoveBackground'; Type = 'DWord'; Value = 1 }
        # deprovisioned: Windows won't install them again for new users
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.Copilot_8wekyb3d8bbwe'; Value = 'Key' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe'; Value = 'Key' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.Office.ActionsServer_8wekyb3d8bbwe'; Value = 'Key' }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\aimgr_8wekyb3d8bbwe'; Value = 'Key' }
    )
}
