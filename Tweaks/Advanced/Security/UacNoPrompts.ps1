# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable user account control", the values
# security-uac-off (EnableLUA) doesn't set.
@{
    Id          = 'security-uac-no-prompts'
    Name        = 'Elevate administrators without asking'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    Guided      = $false
    Description = 'UAC stays on, but an administrator''s programs elevate silently and the secure desktop never dims the screen. Anything you run can take full control.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'ConsentPromptBehaviorAdmin'; Type = 'DWord'; Value = 0; Default = 5 }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'PromptOnSecureDesktop'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
