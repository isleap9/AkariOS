# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable XBOX mode": no app is set as the
# full screen gaming home.
@{
    Id          = 'gaming-no-xbox-full-screen'
    Name        = 'No Xbox full screen experience'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Description = 'The Xbox app isn''t used as a full screen home for games (the handheld "Xbox mode"), so Windows boots to the normal desktop.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GamingConfiguration'; Name = 'GamingHomeApp'; Type = 'String'; Value = ''; Default = $null }
    )
}
