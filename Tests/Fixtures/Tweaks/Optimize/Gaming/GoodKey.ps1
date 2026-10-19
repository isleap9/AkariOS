@{
    Id          = 'good-key'
    Name        = 'Good key'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Fixture: deletes a whole key (Revert recreates it empty), plus a Binary value.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\AkariTest\Loader\Key'; Value = $null; Default = 'Key' }
        @{ Path = 'HKCU:\Software\AkariTest\Loader'; Name = 'Bin'; Type = 'Binary'; Value = [byte[]](1, 2, 3); Default = $null }
    )
}
