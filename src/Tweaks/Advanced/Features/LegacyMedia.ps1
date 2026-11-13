# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json "WPFFeatureslegacymedia".
# Windows features (Files\Features.psd1): Apply turns them on, Revert puts each back as on a fresh Windows.
@{
    Id          = 'features-legacy-media'
    Name        = 'Legacy media (WMP, DirectPlay)'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Safe'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns on Windows Media Player Legacy, Media Features, DirectPlay and Legacy Components, which old games and programs need. Revert leaves Windows Media Player on and DirectPlay off, as Windows ships.'
    Detect      = { . "$AkariTweakDir\Files\Features.ps1"; Get-FeatureToggleState 'features-legacy-media' }
    Apply       = { . "$AkariTweakDir\Files\Features.ps1"; Enable-FeatureToggle 'features-legacy-media' }
    Revert      = { . "$AkariTweakDir\Files\Features.ps1"; Reset-FeatureToggle 'features-legacy-media' }
}
