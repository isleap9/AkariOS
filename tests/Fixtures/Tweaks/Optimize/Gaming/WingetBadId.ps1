# Action: fixture, a Winget id that could break out of the generated command (rejected)
@{
    Id          = 'winget-bad-id'
    Name        = 'Fixture WingetBadId'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Kind        = 'Action'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Winget      = "Akari.Test'; Remove-Item x"
}
