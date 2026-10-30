@{
    Id          = 'reg-no-default'
    Name        = 'Fixture'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'A'; Type = 'DWord'; Value = 0 }
}
