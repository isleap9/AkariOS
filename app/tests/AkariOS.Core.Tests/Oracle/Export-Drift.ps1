# The reference for the native drift check (app/AkariOS.Core/Tweaks/Drift.cs): src\Core\State.ps1's Test-AkariDrift on
# the cases DriftTests writes, and an expected.json written by Set-AkariExpected at -Expected (the native ExpectedStore
# reads it back).
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Expected, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
foreach ($f in 'Log', 'Registry', 'State') { . (Join-Path $Src "Core\$f.ps1") }

# 5.1's ConvertFrom-Json hands a top-level array on as one object: foreach goes through it
$all = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json
$result = @(foreach ($c in $all) { Test-AkariDrift "$($c.Kind)" "$($c.Mode)" $c.Value "$($c.State)" $c.Current })

$AkariExpectedPath = $Expected
Set-AkariExpected @{ Id = 'tog-on'; Kind = 'Toggle' } 'Apply'
Set-AkariExpected @{ Id = 'tog-off'; Kind = 'Toggle' } 'Revert'
Set-AkariExpected @{ Id = 'cho-3'; Kind = 'Choice' } 'Apply' 3
Set-AkariExpected @{ Id = 'cho-text'; Kind = 'Choice' } 'Apply' 'high'
Set-AkariExpected @{ Id = 'cho-rec'; Kind = 'Choice' } 'Apply'
Set-AkariExpected @{ Id = 'cho-back'; Kind = 'Choice' } 'Revert' 9
Set-AkariExpected @{ Id = 'act'; Kind = 'Action' } 'Apply'
Set-AkariExpected @{ Id = 'appx/x'; Kind = 'Toggle'; EntryKind = 'AppxRemove' } 'Apply'
[IO.File]::WriteAllText($Out, (ConvertTo-Json @($result) -Compress), [Text.UTF8Encoding]::new($false))
