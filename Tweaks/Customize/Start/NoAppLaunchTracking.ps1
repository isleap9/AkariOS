# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable show recently opened items in
# start, jump lists and file explorer": the value start-hide-recent-items doesn't set.
@{
    Id          = 'start-no-app-launch-tracking'
    Name        = 'Don''t track app launches'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'Turns off "Let Windows improve Start and search results by tracking app launches", so Start stops ranking apps by how often you open them.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackProgs'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
