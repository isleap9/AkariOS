# Action: fixture, After without Winget (rejected)
@{
    Id          = 'after-no-winget'
    Name        = 'Fixture AfterNoWinget'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Kind        = 'Action'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Apply       = { 'x' }
    After       = { 'y' }
}
