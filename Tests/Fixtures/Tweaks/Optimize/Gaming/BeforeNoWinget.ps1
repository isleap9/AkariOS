# Action: fixture, Before without Winget
@{
    Id          = 'before-no-winget'
    Name        = 'Before no winget'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Kind        = 'Action'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Before      = { 'x' }
    Apply       = { 'y' }
}
