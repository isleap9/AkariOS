# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): OneDrive's installer out of
# the image, so it never installs for new users, and the documented DisableFileSyncNGSC policy. The same files zISO
# Tweaker removes (MIT, CREDITS.md).
@{
    Name        = 'OneDrive'
    Description = 'OneDrive never installs and its sync is off. Install it from Downloads later if you want it.'
    Kind        = 'Files'
    Risk        = 'Safe'
    Order       = 6
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name = 'DisableFileSyncNGSC'; Type = 'DWord'; Value = 1 }
        # the default user's first sign-in starts no OneDrive setup
        @{ Path = 'NTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Name = 'OneDriveSetup'; Value = $null }
    )
    Remove      = @(
        'Windows\System32\OneDriveSetup.exe'
        'Windows\SysWOW64\OneDriveSetup.exe'
        'Windows\System32\OneDrive.ico'
    )
}
