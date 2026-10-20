# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'explorer-show-hidden-files'
    Name        = 'Show hidden files'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Shows hidden files, folders and drives (dimmed). Protected system files stay hidden.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Hidden'; Type = 'DWord'; Value = 1; Default = 2 }
}
