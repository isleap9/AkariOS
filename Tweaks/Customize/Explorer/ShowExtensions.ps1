# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'explorer-show-extensions'
    Name        = 'Show file extensions'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Shows .exe, .txt and the rest after file names, so you can see what a file really is.'
    Registry    = @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Type = 'DWord'; Value = 0; Default = 1 }
}
