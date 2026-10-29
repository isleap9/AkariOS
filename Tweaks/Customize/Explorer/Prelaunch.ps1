# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Enable file explorer prelaunch".
@{
    Id          = 'explorer-prelaunch'
    Name        = 'Preload File Explorer'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Description = 'Windows keeps File Explorer loaded in the background so its windows open faster, for a little more memory. Recent Windows 11 builds only.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShouldPrelaunchFileExplorer'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
