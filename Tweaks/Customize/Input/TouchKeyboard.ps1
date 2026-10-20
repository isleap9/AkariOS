# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'input-touch-keyboard'
    Name        = 'No touch keyboard'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The touch keyboard and its taskbar button don''t show up.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\1.7'; Name = 'TouchKeyboardTapInvoke'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\1.7'; Name = 'TipbandDesiredVisibility'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
