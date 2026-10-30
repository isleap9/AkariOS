# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Disable Device Encryption": only its
# PreventDeviceEncryption value. ZOICWARE also decrypts every BitLocker drive and writes BDESVC's start type
# (advanced-services-off's) and two status values; decrypting is left to the user. Revert deletes the value.
@{
    Id          = 'security-prevent-device-encryption'
    Name        = 'No automatic device encryption'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Windows no longer encrypts the system drive on its own (device encryption on sign-in with a Microsoft account). A drive that is already encrypted stays so: turn it off in Settings > Privacy & security > Device encryption, or BitLocker in Control Panel.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker'; Name = 'PreventDeviceEncryption'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
