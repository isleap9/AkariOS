# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'performance-visual-effects'
    Name        = 'Lighter visual effects'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Fewer animations, fades and shadows; window contents not drawn while dragging. Smooth fonts and thumbnails stay.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name = 'VisualFXSetting'; Type = 'DWord'; Value = 3; Default = $null }
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'UserPreferencesMask'; Type = 'Binary'; Value = [byte[]](0x90, 0x12, 0x03, 0x80, 0x12, 0x00, 0x00, 0x00); Default = [byte[]](0x9e, 0x1e, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00) }
        @{ Path = 'HKCU:\Control Panel\Desktop\WindowMetrics'; Name = 'MinAnimate'; Type = 'String'; Value = '0'; Default = '1' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAnimations'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'EnableAeroPeek'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ListviewAlphaSelect'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'DragFullWindows'; Type = 'String'; Value = '0'; Default = '1' }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ListviewShadow'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
