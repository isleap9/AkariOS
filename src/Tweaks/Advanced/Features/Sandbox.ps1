# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json "WPFFeaturesSandbox".
# Windows features (Files\Features.psd1): Apply turns them on, Revert puts each back as on a fresh Windows.
@{
    Id          = 'features-sandbox'
    Name        = 'Windows Sandbox'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Caution'
    Requires    = 'Pro'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns on Windows Sandbox, a throwaway desktop for running programs you dont trust. It also turns on the hypervisor, which costs some gaming performance and trips a few anti-cheats.'
    Detect      = { . "$AkariTweakDir\Files\Features.ps1"; Get-FeatureToggleState 'features-sandbox' }
    Apply       = { . "$AkariTweakDir\Files\Features.ps1"; Enable-FeatureToggle 'features-sandbox' }
    Revert      = { . "$AkariTweakDir\Files\Features.ps1"; Reset-FeatureToggle 'features-sandbox' }
}
