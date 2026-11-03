# The reference for Tweak classes whose blocks call Core's tool wrappers and write the registry (app/AkariOS.Tweaks):
# each Tweak in -Ids has its Detect, Apply, Revert and After blocks (After once per mode, "After.Apply" /
# "After.Revert") run with the wrappers replaced by recorders, so nothing on this PC changes (rule 12); the calls are
# written as JSON for the Tweaks tests, one line each:
#   "powercfg <args>", "bcdedit <args>", "bcd <id>" (Read-AkariBcd), "w32tm <args>", "regimport <text>",
#   "set <path>|<name>|<value>|<type>" (a [byte[]] value as 'ab,01' hex), "remove <path>|<name>",
#   "row <path>|<name>|<value>|<default>" (each row handed to Get-AkariRegistryState), "result <text>" (Detect's).
# Answers: powercfg /list with -PlanList (one GUID per line, as powercfg prints them), Read-AkariBcd with -BcdLines
# ('|'-separated). Only the blocks of the Ids run, so a Tweak whose blocks call anything else (Stop-Service…) is never
# listed. -TestRoot: Resolve-AkariRegPath points every hive at HKCU\<it>\<hive> (a test key the C# test filled), so a
# block's Get-ChildItem reads the test key, never the real hives.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [string]$Ids = '', [string]$PlanList = '',
    [string]$BcdLines = '', [string]$TestRoot = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\Registry.ps1')
$script:Calls = [Collections.Generic.List[string]]::new()
$script:Plans = @($PlanList.Split(',') | Where-Object { $_ } | ForEach-Object { "Power Scheme GUID: $_  (Plan)" })
function Format-Value($Value) { if ($Value -is [byte[]]) { ($Value | ForEach-Object { $_.ToString('x2') }) -join ',' } else { "$Value" } }
function Invoke-AkariPowerCfg { $script:Calls.Add("powercfg $($args -join ' ')"); if ($args[0] -eq '/list') { $script:Plans } }
function Invoke-AkariBcdEdit([string]$Arguments) { $script:Calls.Add("bcdedit $Arguments"); 0 }
function Read-AkariBcd([string]$Id = '{current}') { $script:Calls.Add("bcd $Id"); @($BcdLines.Split('|') | Where-Object { $_ }) }
function Invoke-AkariW32tm { $script:Calls.Add("w32tm $($args -join ' ')") }
function Import-AkariRegText([string]$Text) { $script:Calls.Add("regimport $Text"); 0 }
function Set-Reg($Path, $Name, $Value, $Type = 'DWord') { $script:Calls.Add("set $Path|$Name|$(Format-Value $Value)|$Type") }
function Remove-Reg($Path, $Name) { $script:Calls.Add("remove $Path|$Name") }
function Get-AkariRegistryState([hashtable[]]$Entries) {
    foreach ($e in $Entries) { $script:Calls.Add("row $($e.Path)|$($e.Name)|$(Format-Value $e.Value)|$(Format-Value $e.Default)") }
    'Default'
}
function Resolve-AkariRegPath([string]$Path) {
    if (-not $TestRoot) { return 'Registry::HKEY_CURRENT_USER\Software\AkariTest\none' }
    if ($Path -match '^(HKCU|HKLM):\\?(.*)$') { return "Registry::HKEY_CURRENT_USER\$TestRoot\$($Matches[1])\$($Matches[2])" }
    $Path
}
function Get-AkariOSBuild { 26100 }

$root = Join-Path $Src 'Tweaks'
$tweaks = (Get-AkariTweaks $root).Tweaks
$result = [ordered]@{}
foreach ($id in @($Ids.Split(',') | Where-Object { $_ })) {
    $t = $tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    $AkariTweakDir = Split-Path $t.Source
    $entry = [ordered]@{}
    foreach ($b in 'Detect', 'Apply', 'Revert') {
        if (-not $t.$b) { continue }
        $script:Calls.Clear()
        $said = & $t.$b
        if ($b -eq 'Detect') { $script:Calls.Add("result $said") }
        $entry[$b] = @($script:Calls)
    }
    if ($t.After) {
        foreach ($AkariMode in 'Apply', 'Revert') {
            $script:Calls.Clear()
            & $t.After | Out-Null
            $entry["After.$AkariMode"] = @($script:Calls)
        }
    }
    $result[$id] = $entry
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
