# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Game Mode" (it only opens the page; gaming-game-mode is
# the setting).
# Action: it opens a page and changes nothing, so there is nothing to revert.
@{
    Id          = 'gaming-open-game-mode'
    Name        = 'Game Mode settings'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens Settings > Gaming > Game Mode.'
    Apply       = { Start-Process 'ms-settings:gaming-gamemode' }
}
