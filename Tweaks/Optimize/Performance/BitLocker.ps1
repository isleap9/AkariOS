# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup\1 BitLocker (One-click does it in steptwo.ps1).
# Action: turning BitLocker back on needs the user's own choices (recovery key, which drives), in BitLocker settings.
@{
    Id          = 'performance-bitlocker-off'
    Name        = 'Decrypt BitLocker drives'
    Section     = 'Optimize'
    Category    = 'Performance'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'Turns BitLocker off and decrypts every encrypted drive in the background (faster disk access). Turn it back on in BitLocker settings.'
    Detect      = {
        if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) { return $true }
        -not @(Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.ProtectionStatus -eq 'On' -or $_.VolumeStatus -ne 'FullyDecrypted' }).Count
    }
    Apply       = {
        if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) { 'BitLocker is not on this edition of Windows'; return }
        Get-BitLockerVolume -ErrorAction SilentlyContinue | Where-Object { $_.ProtectionStatus -eq 'On' -or $_.VolumeStatus -ne 'FullyDecrypted' } |
            ForEach-Object { Disable-BitLocker -MountPoint $_.MountPoint -ErrorAction SilentlyContinue | Out-Null; "Decrypting $($_.MountPoint)" }
    }
}
