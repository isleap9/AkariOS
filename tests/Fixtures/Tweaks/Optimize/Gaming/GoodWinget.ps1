# Action: fixture app install (fake winget ids)
@{
    Id          = 'good-winget'
    Name        = 'Fixture GoodWinget'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Winget      = 'Akari.Test.One', 'Akari.Test++'
    After       = { 'after' }
}
