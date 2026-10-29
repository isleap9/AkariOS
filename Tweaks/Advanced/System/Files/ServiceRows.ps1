# Steps advanced-services-off's blocks share, dot-sourced inside them: . "$AkariTweakDir\Files\ServiceRows.ps1"
# Not a tweak (the Loader reads only <Section>\<Category>\*.ps1). The start types are in services.psd1.

# the Start rows of a pick (Off, Light, Manual or Default) for the services this Windows has: Value = the pick's
# start type, Default = Windows'
function Get-ServiceRows([string]$Pick) {
    $d = Import-PowerShellDataFile "$AkariTweakDir\Files\services.psd1"
    foreach ($s in $d.Services) {
        $v = switch ($Pick) {
            'Off' { if ($null -ne $s.Off) { $s.Off } else { $s.Default } }
            'Light' { if ($s.Name -in $d.Light) { 4 } else { $s.Default } }
            'Manual' { if ($s.Name -in $d.Manual) { 3 } else { $s.Default } }
            default { $s.Default }
        }
        $row = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\$($s.Name)"; Name = 'Start'; Type = 'DWord'; Value = $v; Default = $s.Default }
        if (Test-Path -LiteralPath (Resolve-AkariRegPath $row.Path)) { $row }
    }
}

# the pick every row is at now, or $null (a start type changed by hand or by another tool)
function Get-ServicePick {
    $now = @{}
    foreach ($r in @(Get-ServiceRows 'Default')) { $now[$r.Path] = Get-AkariRegValue $r.Path 'Start' }
    foreach ($pick in 'Default', 'Off', 'Light', 'Manual') {
        if (-not @(Get-ServiceRows $pick | Where-Object { -not (Test-AkariRegMatch $now[$_.Path] $_.Value) }).Count) { return $pick }
    }
    $null
}

# sets every row to the pick: as TrustedInstaller (many service keys are protected), then as admin for what that missed
function Set-ServicePick([string]$Pick) {
    $rows = @(Get-ServiceRows $Pick)
    Invoke-AkariRegistryTrusted $rows Apply
    foreach ($r in $rows) { try { Invoke-AkariRegistry @($r) Apply } catch { "Kept by Windows: $($r.Path) ($($_.Exception.Message))" } }
}
