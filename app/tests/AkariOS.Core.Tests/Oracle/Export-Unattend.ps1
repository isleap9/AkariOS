# The reference for the native Unattend Generator (app/AkariOS.Core/Unattend/): src\Core\Unattend.ps1 on the cases
# UnattendOracleTests writes, written back as JSON. Each case's fields are: a file's (ConvertFrom-AkariUnattend on
# File, a fixture made on Schneegans' site), the form's Defaults (src\UI\Unattend.psd1), the ISO Builder's local
# account fields (Get-AkariIsoAnswerFields on those Defaults: Iso = user, password, skip setup questions), the page's
# start fields (Get-AkariUnattendStart, Start = this PC's language, locale, keyboard, region, time zone) or none;
# then Change put over them. For each: the fields, ConvertTo-AkariUnattendQuery, and New-AkariUnattend's bytes
# (base64) or its error. Queries: ConvertFrom-AkariUnattendQuery on each URL. Also Get-AkariUnattendSamples.
# Nothing is written anywhere but -Out.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Unattend.ps1')
$window = $null
. (Join-Path $Src 'UI\IsoBuilder.ps1')
# the page's start fields (UI\Unattend.ps1 reads $Root\UI\Unattend.psd1; it only defines functions)
$Root = $Src
. (Join-Path $Src 'UI\Unattend.ps1')
function Get-AkariUnattendDefaults { $script:Pc }
$defaults = (Import-PowerShellDataFile (Join-Path $Src 'UI\Unattend.psd1')).Defaults

# every value as a list of strings (a field holds one value or several)
function ConvertTo-OracleFields([hashtable]$Fields) {
    $o = [ordered]@{}
    foreach ($k in @($Fields.Keys | Sort-Object)) { $o[[string]$k] = @(@($Fields[$k]) | ForEach-Object { [string]$_ }) }
    $o
}

$c = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json
$result = [ordered]@{ Cases = @(); Queries = @(); Samples = $null }

if ($null -ne $c.Cases) { $result.Cases = @(foreach ($case in @($c.Cases)) {
    $f = @{}
    if ($case.File) { $f = ConvertFrom-AkariUnattend ([IO.File]::ReadAllText($case.File)); if ($null -eq $f) { $f = @{} } }
    elseif ($case.Defaults) { $f = @{} + $defaults }
    elseif ($case.Iso) { $f = Get-AkariIsoAnswerFields $defaults ([string]$case.Iso[0]) ([string]$case.Iso[1]) ([bool]$case.Iso[2]) }
    elseif ($null -ne $case.Start) {
        # the form's starting fields (Get-AkariUnattendStart), this PC's settings answered by the case
        $script:Pc = @{}
        foreach ($p in $case.Start.PSObject.Properties) { $script:Pc[$p.Name] = $p.Value }
        $f = Get-AkariUnattendStart
    }
    if ($null -ne $case.Change) {
        foreach ($p in $case.Change.PSObject.Properties) {
            # ConvertFrom-Json keeps a one-item array as an array
            $f[$p.Name] = if ($p.Value -is [array]) { , @($p.Value | ForEach-Object { [string]$_ }) } else { [string]$p.Value }
        }
    }
    $bytes = ''; $err = ''
    try { $bytes = [Convert]::ToBase64String((New-AkariUnattend $f)) } catch { $err = $_.Exception.Message }
    [ordered]@{ Fields = (ConvertTo-OracleFields $f); Query = (ConvertTo-AkariUnattendQuery $f); Bytes = $bytes; Error = $err }
}) }

if ($null -ne $c.Queries) { $result.Queries = @(foreach ($q in @($c.Queries)) { ConvertTo-OracleFields (ConvertFrom-AkariUnattendQuery $q) }) }

$s = Get-AkariUnattendSamples
$samples = [ordered]@{}
foreach ($k in @($s.Keys | Sort-Object)) { $samples[$k] = [string]$s[$k] }
$result.Samples = $samples

[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
