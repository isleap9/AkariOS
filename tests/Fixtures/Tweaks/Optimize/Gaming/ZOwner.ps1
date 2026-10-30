@{
    Id          = 'z-owner'
    Name        = 'Z owner'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture: sets the value good-registry already owns.'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'A'; Type = 'DWord'; Value = 1; Default = $null }
}
