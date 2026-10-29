# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Privacy deny foreground text access",
# "... text and image generation", "... human presence", "... background spatial perception", "... eye tracker",
# "... get diagnostic info" and "... motion": the newer app permissions, as one Toggle.
@{
    Id          = 'privacy-new-permissions-deny'
    Name        = 'Block apps from the newer permissions'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Apps can''t use Windows'' AI models, read on-screen text, sense your presence, eye tracking, motion, spatial perception or diagnostic info.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\foregroundTextAccess'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessSystemAIModels'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessHumanPresence'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessBackgroundSpatialPerception'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessGazeInput'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsGetDiagnosticInfo'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessMotion'; Type = 'DWord'; Value = 2; Default = $null }
    )
}
