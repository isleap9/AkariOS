@{
    Id          = 'choice-bad-rec'
    Name        = 'Fixture'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture.'
    Kind        = 'Choice'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'P'; Type = 'DWord' }
    Choices     = @(
        @{ Value = 0x26; Label = '0x26' }
        @{ Value = 0x28; Label = '0x28' }
    )
    Default     = 2
    Recommended = 0x99
}
