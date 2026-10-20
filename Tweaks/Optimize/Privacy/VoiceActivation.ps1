# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'privacy-voice-activation'
    Name        = 'Voice activation off'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Apps can''t listen for a wake word.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps'; Name = 'AgentActivationEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps'; Name = 'AgentActivationLastUsed'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
