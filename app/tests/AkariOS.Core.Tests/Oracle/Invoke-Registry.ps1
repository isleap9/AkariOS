# The reference for the native RegistryEngine: the PowerShell app's Core\Registry.ps1 (dot-sourced: functions only)
# on rows in -Rows (a .ps1 returning @( @{ Path; Name; Type; Value; Default } ... ), paths under the test key
# HKCU:\Software\AkariTest\<guid>), as RegistryOracleTests runs it: -Mode Apply / Revert runs Invoke-AkariRegistry
# first, then the rows' Get-AkariRegistryState is written to -Out. HKCU is the user running the tests (rule 6's
# real-user lookup is set to them), so both apps read and write the same test key.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Rows, [ValidateSet('State', 'Apply', 'Revert')][string]$Mode = 'State',
    [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Registry.ps1')
$script:AkariUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
foreach ($r in @(& $Rows)) { if ($r.Path -notlike 'HKCU:\Software\AkariTest\*') { throw "not a test key: $($r.Path)" } }
$entries = [hashtable[]]@(& $Rows)
if ($Mode -ne 'State') { Invoke-AkariRegistry $entries $Mode }
[IO.File]::WriteAllText($Out, (ConvertTo-Json @{ State = (Get-AkariRegistryState $entries) } -Compress), [Text.UTF8Encoding]::new($false))
