# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable low disk space checks".
@{
    Id          = 'system-no-low-disk-warning'
    Name        = 'No low disk space warnings'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Explorer stops checking free space and popping up "low disk space" warnings.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoLowDiskSpaceChecks'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
