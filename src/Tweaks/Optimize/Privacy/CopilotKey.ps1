# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable Windows AI": the two values
# privacy-copilot-ai and taskbar-hide-copilot don't set.
@{
    Id          = 'privacy-copilot-key-off'
    Name        = 'Copilot key and taskbar companion off'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'The Copilot key on newer keyboards opens nothing, and the taskbar''s AI companion stays hidden.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarCompanion'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\CopilotKey'; Name = 'SetCopilotHardwareKey'; Type = 'String'; Value = ''; Default = $null }
    )
}
