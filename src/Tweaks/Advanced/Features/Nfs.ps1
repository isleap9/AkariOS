# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json "WPFFeaturenfs".
# Windows features (Files\Features.psd1): Apply turns them on, Revert puts each back as on a fresh Windows.
@{
    Id          = 'features-nfs'
    Name        = 'NFS client'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Caution'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns on the Network File System client, for opening shares on Linux servers and NAS boxes.'
    Detect      = { . "$AkariTweakDir\Files\Features.ps1"; Get-FeatureToggleState 'features-nfs' }
    Apply       = { . "$AkariTweakDir\Files\Features.ps1"; Enable-FeatureToggle 'features-nfs' }
    Revert      = { . "$AkariTweakDir\Files\Features.ps1"; Reset-FeatureToggle 'features-nfs' }
}
