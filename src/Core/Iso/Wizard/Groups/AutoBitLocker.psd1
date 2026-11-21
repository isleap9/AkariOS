# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): automatic device encryption
# off. PreventDeviceEncryption = 1 is the value Microsoft documents for it; BitLocker itself stays for anyone who turns
# it on by hand.
@{
    Name        = 'Automatic BitLocker encryption'
    Description = 'Windows doesn''t encrypt the system drive by itself during setup. You can still turn BitLocker on later.'
    Kind        = 'Settings'
    Risk        = 'Safe'
    Order       = 9
    Registry    = @(
        @{ Path = 'SYSTEM\ControlSet001\Control\BitLocker'; Name = 'PreventDeviceEncryption'; Type = 'DWord'; Value = 1 }
    )
}
