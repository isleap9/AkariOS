# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "Updates Drivers Block", Updates: Block / Unblock. Group
# policies (Pro and up; Home ignores them). Windows Update is pointed at a server that isn't there (this PC,
# 127.0.0.1; the old script used a joke domain). Its ExcludeWUDriversInQualityUpdate belongs to
# update-block-driver-updates-policy. "Block (Bootable USB)" is not ported (it only put a restart script on the stick).
@{
    Id          = 'update-block-windows-update'
    Name        = 'Block Windows Update (group policy)'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Advanced'
    Requires    = 'Pro'
    Guided      = $false
    Description = 'Windows Update stops: no automatic updates, its Settings page is hidden, and it looks for updates on a server that doesn''t exist. No security updates either until you switch this back.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DoNotConnectToWindowsUpdateInternetLocations'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'UpdateServiceUrlAlternate'; Type = 'String'; Value = 'http://127.0.0.1'; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'WUServer'; Type = 'String'; Value = 'http://127.0.0.1'; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'WUStatusServer'; Type = 'String'; Value = 'http://127.0.0.1'; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetDisableUXWUAccess'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'UseWUServer'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
