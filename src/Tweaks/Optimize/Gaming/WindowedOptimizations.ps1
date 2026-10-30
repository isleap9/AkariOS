# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'gaming-windowed-optimizations'
    Name        = 'Optimizations for windowed games'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Description = 'Windowed and borderless games present like fullscreen ones (lower latency); variable refresh rate stays as the game sets it.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'; Name = 'DirectXUserGlobalSettings'; Type = 'String'; Value = 'SwapEffectUpgradeEnable=1;VRROptimizeEnable=0;'; Default = $null }
    )
}
