@{
    Id          = 'good-registry'
    Name        = 'Fixture'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'B'; Type = 'DWord'; Value = 0; Default = 1 }
}
