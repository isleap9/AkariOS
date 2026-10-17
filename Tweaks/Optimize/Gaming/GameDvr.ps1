@{
    Id          = 'disable-game-dvr'
    Name        = 'Disable Game DVR'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Turns off background game recording.'
    Registry    = @(
        @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
