# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'input-language-bar'
    Name        = 'Language bar and hotkeys'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Hides the language bar extras; switch input language with left Alt+Shift, keyboard layout with Ctrl+Shift.'
    Registry    = @(
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\CTF\LangBar'; Name = 'ExtraIconsOnMinimized'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\CTF\LangBar'; Name = 'Label'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\CTF\LangBar'; Name = 'ShowStatus'; Type = 'DWord'; Value = 3; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\CTF\LangBar'; Name = 'Transparency'; Type = 'DWord'; Value = 255; Default = $null }
        @{ Path = 'HKCU:\Keyboard Layout\Toggle'; Name = 'Language Hotkey'; Type = 'String'; Value = '1'; Default = $null }
        @{ Path = 'HKCU:\Keyboard Layout\Toggle'; Name = 'Hotkey'; Type = 'String'; Value = '1'; Default = $null }
        @{ Path = 'HKCU:\Keyboard Layout\Toggle'; Name = 'Layout Hotkey'; Type = 'String'; Value = '2'; Default = $null }
    )
}
