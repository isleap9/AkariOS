@{
    Id          = 'key-row-bad'
    Name        = 'Key row bad'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Description = 'Fixture: a key row whose Value is not Key or $null.'
    Registry    = @{ Path = 'HKCU:\Software\AkariTest\Loader\K'; Value = 1; Default = $null }
}
