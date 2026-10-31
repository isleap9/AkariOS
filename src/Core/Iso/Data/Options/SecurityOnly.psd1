# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Sec-UpdatesOnly.
@{
    Name        = 'Security updates only'
    Description = 'Defers feature and quality updates for two years and leaves out drivers, feature packs and optional content.'
    Group       = 'Update'
    Order       = 2
    Excludes    = @('DisableUpdates')
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetAllowOptionalContent'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DeferFeatureUpdates'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DeferFeatureUpdatesPeriodInDays'; Type = 'DWord'; Value = 730 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DeferQualityUpdates'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DeferQualityUpdatesPeriodInDays'; Type = 'DWord'; Value = 730 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'ExcludeWUDriversInQualityUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; Name = 'ExcludeWUDriversInQualityUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Device Metadata'; Name = 'PreventDeviceMetadataFromNetwork'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DriverSearching'; Name = 'DontPromptForWindowsUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DriverSearching'; Name = 'DontSearchWindowsUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DriverSearching'; Name = 'DriverUpdateWizardWuSearchEnabled'; Type = 'DWord'; Value = 0 }
        # every classification but Security Updates: Critical, Definition, Feature Packs, Service Packs, Tools, Update
        # Rollups, Updates, Non-critical, Drivers, Feature Updates
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'ExcludeUpdateClassifications'; Type = 'String'; Value = '{e6cf1350-c01b-414d-a61f-263d3d4dd9f9};{e0789628-ce08-4437-be74-2495b842f43b};{b54e7d24-7add-49f4-88bb-9837d47477fb};{68c5b0a3-d1a6-4553-ae49-01d3a7827828};{b4832bd8-e735-4766-9727-7d0ffa644277};{28bc8804-5382-4bae-93aa-13c905f28542};{cd5ffd1e-e257-4a05-9d88-c83a7125d4c9};{0f1afbec-90ef-4651-9e37-030fedc944c8};{ebfc1fc5-71a4-4f7b-9aca-3b9a503104a0};{9920c092-3d99-4a1b-865a-673135c5a4fc}' }
    )
}
