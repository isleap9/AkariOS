@{
    Id          = 'bad-requires'
    Name        = 'Bad requires'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Requires    = 'Mars'
    Description = 'Fixture: unknown Requires.'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'R'; Type = 'DWord'; Value = 0; Default = $null }
}
