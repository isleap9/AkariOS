$Root = Split-Path $PSScriptRoot
$Core = Join-Path $Root 'Core'
$Tw = Join-Path $Root 'Tweaks'

# Every Tweak ported from ZOICWARE (its file names ZOICWARE as the source): Advanced only, outside the AkariOS setup,
# a Default on every row, and a full Apply / Revert round trip. Both hives go to HKCU:\Software\AkariTest\<guid>.
Describe 'ZOICWARE ports' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tk = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    Mock Resolve-AkariRegPath { if ($Path -match '^HKCU:\\(.*)$') { "$tk\$($Matches[1])" } elseif ($Path -match '^HKLM:\\(.*)$') { "$tk\HKLM\$($Matches[1])" } else { $Path } }
    Mock Restart-AkariExplorer { }
    $files = @(Get-ChildItem $Tw -Recurse -Filter *.ps1 | Where-Object { $_.DirectoryName -notmatch '\\Files$' -and (Get-Content $_.FullName -TotalCount 3) -match 'ZOICWARE' })

    try {
        It 'finds the ports (guard)' { $files.Count -ge 21 | Should Be $true }
        It 'redirects both hives (guard)' { Resolve-AkariRegPath 'HKLM:\SOFTWARE\X' | Should Be "$tk\HKLM\SOFTWARE\X" }
        foreach ($f in $files) {
            $t = Import-AkariTweakFile $f.FullName $Tw
            It "$($t.Id): Advanced only, not in the AkariOS setup, a Default on every row" {
                $t.Guided | Should Be $false
                [bool]$t.AkariOS | Should Be $false
                @($t.Registry | Where-Object { -not $_.ContainsKey('Default') }).Count | Should Be 0
            }
            It "$($t.Id): Apply makes it Optimized, Revert puts the Windows default back" {
                (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
                Get-AkariState $t | Should Be 'Optimized'
                (Invoke-AkariTweak $t Revert).Outcome | Should Be 'Reverted'
                Get-AkariState $t | Should Be 'Default'
            }
        }
    } finally {
        if (Test-Path $tk) { Remove-Item $tk -Recurse -Force }
    }
}
