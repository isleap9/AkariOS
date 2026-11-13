# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json "WPFFeaturesdotnet".
# Windows features (Files\Features.psd1): Apply turns them on, Revert puts each back as on a fresh Windows.
@{
    Id          = 'features-dotnet35'
    Name        = '.NET Framework 3.5'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Safe'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns on .NET Framework 3.5 (with 2.0 and 3.0), which older apps and games need. Its files come from a mounted Windows ISO or USB stick when one is plugged in, else from Windows Update.'
    Detect      = { . "$AkariTweakDir\Files\Features.ps1"; Get-FeatureToggleState 'features-dotnet35' }
    Apply       = { . "$AkariTweakDir\Files\Features.ps1"; Enable-FeatureToggle 'features-dotnet35' }
    Revert      = { . "$AkariTweakDir\Files\Features.ps1"; Reset-FeatureToggle 'features-dotnet35' }
}
