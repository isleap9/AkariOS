# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json "WPFFeatureshyperv".
# Windows features (Files\Features.psd1): Apply turns them on, Revert puts each back as on a fresh Windows.
@{
    Id          = 'features-hyperv'
    Name        = 'Hyper-V'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Caution'
    Requires    = 'Pro'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns on Hyper-V, for running virtual machines. It also turns on the hypervisor, which costs some gaming performance and trips a few anti-cheats.'
    Detect      = { . "$AkariTweakDir\Files\Features.ps1"; Get-FeatureToggleState 'features-hyperv' }
    Apply       = { . "$AkariTweakDir\Files\Features.ps1"; Enable-FeatureToggle 'features-hyperv' }
    Revert      = { . "$AkariTweakDir\Files\Features.ps1"; Reset-FeatureToggle 'features-hyperv' }
}
