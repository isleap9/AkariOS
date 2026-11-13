# The Windows features behind each Advanced > Features Toggle (Chris Titus Tech's winutil, MIT, Copyright (c) 2022 CT
# Tech Group LLC: config/feature.json), read by Files\Features.ps1 and the native app. Default = the feature's state on
# a fresh Windows (Revert puts it back). Payload = its files may have to come from Windows Update or a Windows ISO.
@{
    'features-dotnet35'     = @{
        Payload  = $true
        Features = @(
            @{ Name = 'NetFx3'; Default = 'Disabled' }
            @{ Name = 'NetFx4-AdvSrvs'; Default = 'Enabled' }
        )
    }
    'features-hyperv'       = @{ Features = @(@{ Name = 'Microsoft-Hyper-V-All'; Default = 'Disabled' }) }
    'features-sandbox'      = @{ Features = @(@{ Name = 'Containers-DisposableClientVM'; Default = 'Disabled' }) }
    'features-legacy-media' = @{
        Features = @(
            @{ Name = 'WindowsMediaPlayer'; Default = 'Enabled' }
            @{ Name = 'MediaPlayback'; Default = 'Enabled' }
            @{ Name = 'DirectPlay'; Default = 'Disabled' }
            @{ Name = 'LegacyComponents'; Default = 'Disabled' }
        )
    }
    'features-wsl'          = @{
        Features = @(
            @{ Name = 'VirtualMachinePlatform'; Default = 'Disabled' }
            @{ Name = 'Microsoft-Windows-Subsystem-Linux'; Default = 'Disabled' }
        )
    }
    'features-nfs'          = @{
        Features = @(
            @{ Name = 'ServicesForNFS-ClientOnly'; Default = 'Disabled' }
            @{ Name = 'ClientForNFS-Infrastructure'; Default = 'Disabled' }
            @{ Name = 'NFS-Administration'; Default = 'Disabled' }
        )
    }
}
