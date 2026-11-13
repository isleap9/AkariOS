# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleScrollbars".
@{
    Id          = 'accessibility-scrollbars-visible'
    Name        = 'Scroll bars always visible'
    Section     = 'Customize'
    Category    = 'Accessibility'
    Risk        = 'Safe'
    Description = 'Scroll bars in Settings, the Store and other modern apps stay full size instead of shrinking to a thin line.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Accessibility'; Name = 'DynamicScrollbars'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
