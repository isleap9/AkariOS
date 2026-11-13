# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleWindowSnapping".
@{
    Id          = 'system-snap-off'
    Name        = 'Window snapping off'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Dragging a window to an edge or corner no longer resizes it, and Win+arrow keys no longer snap it.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Desktop'; Name = 'WindowArrangementActive'; Type = 'String'; Value = '0'; Default = '1' }
    )
}
