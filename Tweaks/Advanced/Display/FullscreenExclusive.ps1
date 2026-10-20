# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\12 Hardware Legacy Flip. Default = stock Windows
# (fullscreen optimizations, FSEBehaviorMode 2), not the old script's forced-FSO values.
@{
    Id          = 'display-fullscreen-exclusive'
    Name        = 'Fullscreen exclusive (hardware legacy flip)'
    Section     = 'Advanced'
    Category    = 'Display'
    Risk        = 'Caution'
    Description = 'Fullscreen games run in real exclusive mode instead of fullscreen optimizations. Alt-Tab gets slower.'
    Registry    = @(
        @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_DXGIHonorFSEWindowsCompatible'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_FSEBehaviorMode'; Type = 'DWord'; Value = 2; Default = 2 }
        @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_FSEBehavior'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_HonorUserFSEBehaviorMode'; Type = 'DWord'; Value = 1; Default = 0 }
    )
}
