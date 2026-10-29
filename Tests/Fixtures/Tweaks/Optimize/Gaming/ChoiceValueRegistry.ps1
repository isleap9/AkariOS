@{
    Id          = 'choice-value-registry'
    Name        = 'Fixture'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Kind        = 'Choice'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'CV'; Type = 'DWord' }
    Choices     = @(
        @{ Value = 'A' }
        @{ Value = 'B' }
    )
    Default     = 'B'
    Recommended = 'A'
    Value       = { 'A' }
    Apply       = { }
    Revert      = { }
}
