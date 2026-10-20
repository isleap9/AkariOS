@{
    Id          = 'disable-memory-compression'
    Name        = 'Disable Memory Compression'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Caution'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Stops Windows compressing memory pages in RAM. Uses less CPU, but more RAM.'
    Detect      = { -not (Get-MMAgent).MemoryCompression }
    Apply       = { Disable-MMAgent -MemoryCompression }
    Revert      = { Enable-MMAgent -MemoryCompression }
}
