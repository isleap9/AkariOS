# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\13 Hardware Composed Independent Flip.
@{
    Id          = 'display-composed-independent-flip'
    Name        = 'Hardware composed independent flip'
    Section     = 'Advanced'
    Category    = 'Display'
    Risk        = 'Caution'
    Reboot      = $true
    Description = 'Windowed games flip right away (ForceFlipTrueImmediateMode) instead of the default hardware independent flip.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler'; Name = 'ForceFlipTrueImmediateMode'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
