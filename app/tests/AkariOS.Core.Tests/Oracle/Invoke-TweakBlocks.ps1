# The reference for Tweak classes whose blocks call powercfg and write the registry (app/AkariOS.Tweaks): each
# Tweak in -Ids has its Apply then its Revert block run with Invoke-AkariPowerCfg, Set-Reg and Remove-Reg replaced by
# recorders, so nothing on this PC changes (rule 12); the calls are written as JSON for the Tweaks tests, one line
# each: "powercfg <args>", "set <path>|<name>|<value>|<type>", "remove <path>|<name>". powercfg /list answers with
# -PlanList (one GUID per line, as powercfg prints them).
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [string]$Ids = '', [string]$PlanList = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Loader.ps1')
$script:Calls = [Collections.Generic.List[string]]::new()
$script:Plans = @($PlanList.Split(',') | Where-Object { $_ } | ForEach-Object { "Power Scheme GUID: $_  (Plan)" })
function Invoke-AkariPowerCfg { $script:Calls.Add("powercfg $($args -join ' ')"); if ($args[0] -eq '/list') { $script:Plans } }
function Set-Reg($Path, $Name, $Value, $Type = 'DWord') { $script:Calls.Add("set $Path|$Name|$Value|$Type") }
function Remove-Reg($Path, $Name) { $script:Calls.Add("remove $Path|$Name") }
function Get-AkariOSBuild { 26100 }

$root = Join-Path $Src 'Tweaks'
$tweaks = (Get-AkariTweaks $root).Tweaks
$result = [ordered]@{}
foreach ($id in @($Ids.Split(',') | Where-Object { $_ })) {
    $t = $tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    $AkariTweakDir = Split-Path $t.Source
    $entry = [ordered]@{}
    foreach ($b in 'Apply', 'Revert') {
        $script:Calls.Clear()
        & $t.$b | Out-Null
        $entry[$b] = @($script:Calls)
    }
    $result[$id] = $entry
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
