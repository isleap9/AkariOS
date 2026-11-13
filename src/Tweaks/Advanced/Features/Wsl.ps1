# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json "WPFFeaturewsl".
# Windows features (Files\Features.psd1): Apply turns them on, Revert puts each back as on a fresh Windows.
@{
    Id          = 'features-wsl'
    Name        = 'Windows Subsystem for Linux'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Caution'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns on WSL and the Virtual Machine Platform, for running Linux programs. Afterwards, install a distro with "wsl --install". It also turns on the hypervisor, which costs some gaming performance and trips a few anti-cheats.'
    Detect      = { . "$AkariTweakDir\Files\Features.ps1"; Get-FeatureToggleState 'features-wsl' }
    Apply       = { . "$AkariTweakDir\Files\Features.ps1"; Enable-FeatureToggle 'features-wsl' }
    Revert      = { . "$AkariTweakDir\Files\Features.ps1"; Reset-FeatureToggle 'features-wsl' }
}
