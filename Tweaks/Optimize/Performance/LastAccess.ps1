# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable last access time".
@{
    Id          = 'performance-last-access-off'
    Name        = 'Don''t update last access times'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Safe'
    Guided      = $false
    Reboot      = $true
    Description = 'NTFS stops writing the "last accessed" date every time a file is read: fewer disk writes. Few programs use that date.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'; Name = 'NtfsDisableLastAccessUpdate'; Type = 'DWord'; Value = 1; Default = 0x80000002 }
    )
}
