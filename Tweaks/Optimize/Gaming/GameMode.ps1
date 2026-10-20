# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'gaming-game-mode'
    Name        = 'Game Mode on'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows gives the game you play priority and pauses updates while it runs.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AutoGameModeEnabled'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
