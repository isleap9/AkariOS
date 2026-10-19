# Action: GameInput comes back with the games or Windows updates that install it, not through an Akari Revert.
# Ported from FR33THY Ultimate "bloatware" (legacy apps).
@{
    Id          = 'remove-gameinput'
    Name        = 'Microsoft GameInput'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Caution'
    Description = 'Microsoft''s game controller service. A few newer games install it again because they need it.'
    Detect      = { -not (Get-AkariMsi '*Microsoft GameInput*') }
    Apply       = { Uninstall-AkariMsi '*Microsoft GameInput*' }
}
