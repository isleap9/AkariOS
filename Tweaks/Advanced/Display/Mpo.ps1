# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\11 Mpo. Its Off option also turned off the windowed
# game optimizations (SwapEffectUpgradeEnable=0): that value belongs to gaming-windowed-optimizations.
@{
    Id          = 'display-mpo-off'
    Name        = 'Turn off multiplane overlay (MPO)'
    Section     = 'Advanced'
    Category    = 'Display'
    Risk        = 'Caution'
    Reboot      = $true
    Description = 'Fixes flicker, black screens and stutter some GPUs get with MPO, at a little extra GPU work.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'; Name = 'OverlayTestMode'; Type = 'DWord'; Value = 5; Default = $null }
    )
}
