# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Remove-OneDrive.
@{
    Name        = 'Remove OneDrive'
    Description = 'Removes OneDrive''s installer from the image, so it never installs, and turns off OneDrive sync.'
    Group       = 'Apps'
    Order       = 2
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name = 'DisableFileSyncNGSC'; Type = 'DWord'; Value = 1 }
    )
    Remove      = @(
        'Windows\System32\OneDriveSetup.exe'
        'Windows\System32\OneDrive.ico'
    )
}
