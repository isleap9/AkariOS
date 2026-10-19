@{
    Id          = 'z-owner-key'
    Name        = 'Z owner key'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture: sets a value inside the key good-key deletes.'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader\Key\Sub'; Name = 'X'; Type = 'DWord'; Value = 1; Default = $null }
}
