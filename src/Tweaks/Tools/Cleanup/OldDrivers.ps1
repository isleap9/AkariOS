# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Remove Old Duplicate Drivers" (Ultimate
# Cleanup): driver packages with the same original .inf, provider and class as a newer one. Read as objects
# (Get-AkariDriverPackages), not from dism's English text; deleted without /force, so one a device uses stays.
# Action: a deleted driver package can't come back.
@{
    Id          = 'cleanup-old-drivers'
    Name        = 'Delete old duplicate drivers'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Deletes older versions of drivers that have a newer version in the driver store (old GPU drivers take gigabytes). Drivers a device still uses are kept.'
    Confirm     = 'Delete old versions of drivers that have a newer version installed? Rolling a device back to them is no longer possible.'
    Apply       = {
        $old = foreach ($g in @(Get-AkariDriverPackages | Group-Object { "$(Split-Path $_.OriginalFileName -Leaf)|$($_.ProviderName)|$($_.ClassName)" } | Where-Object { $_.Count -gt 1 })) {
            $g.Group | Sort-Object { try { [version]$_.Version } catch { [version]'0.0' } }, { $_.Date } -Descending | Select-Object -Skip 1
        }
        $n = 0
        foreach ($d in @($old)) { if ((Remove-AkariDriverPackage $d.Driver) -eq 0) { $n++ } }
        "Deleted $n of $(@($old).Count) old driver packages"
    }
}
