# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Remove-BitLocker (zISO writes its rows as TrustedInstaller).
@{
    Name        = 'Remove BitLocker'
    Description = 'Turns off the BitLocker service and automatic device encryption and removes the BitLocker tools.'
    Group       = 'Security'
    Order       = 2
    Registry    = @(
        @{ Path = 'SYSTEM\ControlSet001\Services\BDESVC'; Name = 'Start'; Type = 'DWord'; Value = 4; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Control\BitLocker'; Name = 'PreventDeviceEncryption'; Type = 'DWord'; Value = 1; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Control\BitlockerStatus'; Name = 'BootStatus'; Type = 'DWord'; Value = 0; Trusted = $true }
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\BitLocker'; Name = 'IsBdeDriverPresent'; Type = 'DWord'; Value = 0; Trusted = $true }
    )
    Remove      = @(
        'Windows\BitLockerDiscoveryVolumeContents\BitLockerToGo.exe'
        'Windows\SysWOW64\BitLockerCsp.dll'
        'Windows\System32\BitLockerCsp.dll'
        'Windows\System32\BitLockerWizard.exe'
        'Windows\System32\BitLockerWizardElev.exe'
        'Windows\System32\BitLockerDeviceEncryption.exe'
        'Windows\System32\*-*\BitLockerWizardElev.exe.mui'
        'Windows\System32\*-*\BitLockerWizard.exe.mui'
    )
}
