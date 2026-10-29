# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Minimize keyboard repeat delay".
@{
    Id          = 'input-short-repeat-delay'
    Name        = 'Shortest key repeat delay'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'A held key starts repeating after the shortest wait Windows allows (about 250 ms instead of 500). Takes effect after signing in again.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'KeyboardDelay'; Type = 'String'; Value = '0'; Default = '1' }
    )
}
