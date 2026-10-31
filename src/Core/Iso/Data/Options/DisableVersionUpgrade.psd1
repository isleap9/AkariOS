# ISO Builder option, from zoicware's zISO Tweaker (MIT, ..\LICENSE-zISOTweaker.txt): ISOTweakerFuncs.psm1
# Disable-VerUpgrade. {DisplayVersion} = the image's own version (25H2...), read from its registry when it is built.
@{
    Name        = 'Disable version upgrades'
    Description = 'Keeps Windows on the image''s version (for example 25H2): no feature update to the next one.'
    Group       = 'Update'
    Order       = 3
    Excludes    = @('DisableUpdates')
    Registry    = @(
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'ProductVersion'; Type = 'String'; Value = 'Windows 11' }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'TargetReleaseVersion'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'TargetReleaseVersionInfo'; Type = 'String'; Value = '{DisplayVersion}' }
    )
}
