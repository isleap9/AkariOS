# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'input-no-print-screen-snipping'
    Name        = 'Print Screen copies the screen'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Print Screen copies the whole screen again instead of opening the Snipping Tool.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Keyboard'; Name = 'PrintScreenKeyForSnippingEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
