# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'input-typing'
    Name        = 'Plain typing'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'No voice typing key, auto-capitals, key sounds, double-space period, typing insights, key background or touch inking.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\input\Settings'; Name = 'IsVoiceTypingKeyEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\1.7'; Name = 'EnableAutoShiftEngage'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\1.7'; Name = 'EnableKeyAudioFeedback'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\1.7'; Name = 'EnableDoubleTapSpace'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\input\Settings'; Name = 'InsightsEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\1.7'; Name = 'IsKeyBackgroundEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\EmbeddedInkControl'; Name = 'EnableInkingWithTouch'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
