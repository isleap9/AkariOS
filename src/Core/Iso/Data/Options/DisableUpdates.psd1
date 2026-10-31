# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Disable-Updates. zISO turns the other two update options off with this one (together they break its build).
@{
    Name        = 'Disable all Windows updates'
    Description = 'Points Windows Update at a server that doesn''t exist, turns its services off and stops driver and Store updates.'
    Group       = 'Update'
    Order       = 1
    Excludes    = @('SecurityOnly', 'DisableVersionUpgrade')
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'WUServer'; Type = 'String'; Value = 'https://DoNotUpdateWindows10.com/' }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'WUStatusServer'; Type = 'String'; Value = 'https://DoNotUpdateWindows10.com/' }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'UpdateServiceUrlAlternate'; Type = 'String'; Value = 'https://DoNotUpdateWindows10.com/' }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetProxyBehaviorForUpdateDetection'; Type = 'DWord'; Value = 0 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetDisableUXWUAccess'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DoNotConnectToWindowsUpdateInternetLocations'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'ExcludeWUDriversInQualityUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'UseWUServer'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SYSTEM\ControlSet001\Services\UsoSvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\DoSvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\wuauserv'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\WaaSMedicSVC'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'; Name = 'SearchOrderConfig'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\WindowsStore'; Name = 'AutoDownload'; Type = 'DWord'; Value = 2 }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; Name = 'DisableOnline'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\Device Metadata'; Name = 'PreventDeviceMetadataFromNetwork'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DriverSearching'; Name = 'DontPromptForWindowsUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DriverSearching'; Name = 'DontSearchWindowsUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\DriverSearching'; Name = 'DriverUpdateWizardWuSearchEnabled'; Type = 'DWord'; Value = 0 }
    )
}
