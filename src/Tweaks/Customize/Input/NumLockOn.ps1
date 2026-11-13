# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleNumLock".
@{
    Id          = 'input-numlock-on'
    Name        = 'Num Lock on at startup'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    Description = 'Num Lock is on at the sign-in screen and when you sign in, so the number pad types numbers.'
    Registry    = @(
        @{ Path = 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; Type = 'String'; Value = '2'; Default = '2147483648' }
        @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; Type = 'String'; Value = '2'; Default = '2147483648' }
    )
}
