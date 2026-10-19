# Action: fixture app install with a step before it (fake winget id)
@{
    Id          = 'good-before'
    Name        = 'Fixture GoodBefore'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Winget      = 'Akari.Test.Before'
    Before      = { 'before' }
}
