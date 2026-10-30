# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Increase icon cache size".
@{
    Id          = 'performance-icon-cache'
    Name        = 'Bigger icon cache'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Safe'
    Guided      = $false
    Reboot      = $true
    Description = 'Explorer keeps up to 4096 icons in memory instead of 500, so folders with many files show their icons faster.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'MaxCachedIcons'; Type = 'String'; Value = '4096'; Default = $null }
    )
}
