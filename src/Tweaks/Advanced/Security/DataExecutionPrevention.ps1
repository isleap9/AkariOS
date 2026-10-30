# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\4 Data Execution Prevention.
# A boot setting (bcdedit), not the registry: Detect reads the current boot entry.
@{
    Id          = 'security-dep-off'
    Name        = 'Turn off Data Execution Prevention'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    Reboot      = $true
    Description = 'Sets DEP to AlwaysOff for every program. Some old games need it; Windows is less safe without it.'
    Detect      = {
        $nx = @(Read-AkariBcd | ForEach-Object { if ($_ -match '^nx\s+(\S+)') { $Matches[1] } })
        if (-not $nx.Count) { 'Default' } elseif ($nx[0] -eq 'AlwaysOff') { 'Optimized' } elseif ($nx[0] -eq 'OptIn') { 'Default' } else { 'Custom' }
    }
    Apply       = { if ((Invoke-AkariBcdEdit '/set {current} nx AlwaysOff') -ne 0) { throw 'bcdedit could not set nx AlwaysOff' } }
    Revert      = { if ((Invoke-AkariBcdEdit '/deletevalue {current} nx') -ne 0) { throw 'bcdedit could not reset nx' } }
}
