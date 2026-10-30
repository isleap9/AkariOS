# Action: fixture, Winget and Apply together (rejected)
@{
    Id          = 'winget-apply'
    Name        = 'Fixture WingetApply'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Kind        = 'Action'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Winget      = 'Akari.Test.One'
    Apply       = { 'x' }
}
