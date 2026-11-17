# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "OVirtualBox".
@{
    Id          = 'install-virtualbox'
    Name        = 'VirtualBox'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'System tools'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Virtual machines. Slow while Hyper-V or Sandbox is on.'
    Winget      = 'Oracle.VirtualBox'
}
