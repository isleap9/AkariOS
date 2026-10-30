@{
    Id          = 'good-registry'
    Name        = 'Good registry'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture: registry Toggle.'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'A'; Type = 'DWord'; Value = 0; Default = $null }
}
