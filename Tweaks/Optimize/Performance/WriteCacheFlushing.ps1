# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\28 Write Cache Buffer Flushing (One-click does the same):
# every SCSI and NVMe disk on this PC. The script's Revert deleted each disk's whole "Disk" key; this removes only the
# value it set, so other disk settings stay.
@{
    Id          = 'performance-write-cache-flushing-off'
    Name        = 'Write-cache buffer flushing off'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Advanced'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Disks don''t flush their write cache on every write (faster writes). A power cut can lose or corrupt recent data: use it with a UPS or a laptop battery.'
    Detect      = {
        $keys = @(foreach ($b in 'SCSI', 'NVME') { Get-ChildItem (Resolve-AkariRegPath "HKLM:\SYSTEM\ControlSet001\Enum\$b") -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Device Parameters' } })
        if (-not $keys.Count) { return 'Unknown' }
        $on = @($keys | Where-Object { (Get-ItemProperty -LiteralPath (Join-Path $_.PSPath 'Disk') -ErrorAction SilentlyContinue).CacheIsPowerProtected -eq 1 }).Count
        if ($on -eq $keys.Count) { 'Optimized' } elseif ($on -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        foreach ($b in 'SCSI', 'NVME') {
            foreach ($k in @(Get-ChildItem (Resolve-AkariRegPath "HKLM:\SYSTEM\ControlSet001\Enum\$b") -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Device Parameters' })) {
                $disk = Join-Path $k.PSPath 'Disk'
                if (-not (Test-Path -LiteralPath $disk)) { New-Item -Path $disk -Force -ErrorAction SilentlyContinue | Out-Null }
                New-ItemProperty -LiteralPath $disk -Name 'CacheIsPowerProtected' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    Revert      = {
        foreach ($b in 'SCSI', 'NVME') {
            foreach ($k in @(Get-ChildItem (Resolve-AkariRegPath "HKLM:\SYSTEM\ControlSet001\Enum\$b") -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Disk' })) {
                Remove-ItemProperty -LiteralPath $k.PSPath -Name 'CacheIsPowerProtected' -ErrorAction SilentlyContinue
            }
        }
    }
}
