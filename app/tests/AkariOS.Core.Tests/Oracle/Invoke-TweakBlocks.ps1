# The reference for Tweak classes whose blocks call Core's tool wrappers and write the registry (app/AkariOS.Tweaks):
# each Tweak in -Ids has its Detect, Apply, Revert and After blocks (After once per mode, "After.Apply" /
# "After.Revert") run with the wrappers replaced by recorders, so nothing on this PC changes (rule 12); the calls are
# written as JSON for the Tweaks tests, one line each:
#   "powercfg <args>", "bcdedit <args>", "bcd <id>" (Read-AkariBcd), "w32tm <args>", "regimport <text>",
#   "set <path>|<name>|<value>|<type>" (a [byte[]] value as 'ab,01' hex), "remove <path>|<name>",
#   "row <path>|<name>|<value>|<default>" (each row handed to Get-AkariRegistryState), "result <text>" (Detect's),
#   "registry <Mode> <row>" / "trusted <Mode> <row>" (Invoke-AkariRegistry / Invoke-AkariRegistryTrusted, a row as
#   above; Get-AkariRegKey reads the test key),
#   "appread <family>", "appimport <family>|<reg text>" (Read- / Import-AkariAppSettings), "stop <process>",
#   "open <target>" (Start-Process), "sleep <seconds>", "delete <path under -UserFolder>" (Remove-Item), and with
#   -UserFolder, after each block, "file <path under it>|<text>" for every file there.
# Answers: powercfg /list with -PlanList (one GUID per line, as powercfg prints them), Read-AkariBcd with -BcdLines
# ('|'-separated), Read-AkariAppSettings with -AppValues ('Key\Name=hex;…' for every family, 'held' = $null);
# Get-AkariAppSettingState is the real one (only that function is read out of Core\AppSetup.ps1). Only the blocks of
# the Ids run, so a Tweak whose blocks call anything else (Stop-Service…) is never listed. -TestRoot:
# Resolve-AkariRegPath points every hive at HKCU\<it>\<hive> (a test key the C# test filled), so a block's
# Get-ChildItem reads the test key, never the real hives. -UserFolder: Get-AkariUserFolder's answer for every name (a
# temp folder the C# test filled; without it, a folder that doesn't exist).
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [string]$Ids = '', [string]$PlanList = '',
    [string]$BcdLines = '', [string]$TestRoot = '', [string]$AppValues = '', [string]$UserFolder = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\Registry.ps1')
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Src 'Core\AppSetup.ps1'), [ref]$null, [ref]$null)
. ([scriptblock]::Create($ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-AkariAppSettingState' }, $true).Extent.Text))
$script:Users = if ($UserFolder) { $UserFolder } else { Join-Path $env:TEMP "akari-none-$([guid]::NewGuid().ToString('N'))" }
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
function Invoke-AkariRegistry($Rows, $Mode) { foreach ($e in @($Rows)) { $script:Calls.Add("registry $Mode $($e.Path)|$($e.Name)|$(Format-Value $e.Value)|$(Format-Value $e.Default)") } }
function Invoke-AkariRegistryTrusted($Rows, $Mode) { foreach ($e in @($Rows)) { $script:Calls.Add("trusted $Mode $($e.Path)|$($e.Name)|$(Format-Value $e.Value)|$(Format-Value $e.Default)") } }
# a key read on the test key (-TestRoot), never the real hives
function Get-AkariRegKey([string]$Path) { if ($TestRoot) { Test-Path -LiteralPath (Resolve-AkariRegPath $Path) } else { $false } }
function Get-AkariOSBuild { 26100 }
function Get-AkariUserFolder([string]$Name) { $script:Users }
function Read-AkariAppSettings([string]$Family) {
    $script:Calls.Add("appread $Family")
    if ($AppValues -eq 'held') { return $null }
    $v = @{}
    foreach ($p in @($AppValues.Split(';') | Where-Object { $_ })) { $k, $h = $p.Split('=', 2); $v[$k] = ConvertFrom-AkariHex $h }
    $v
}
function Import-AkariAppSettings([string]$Family, [string]$RegText) {
    $script:Calls.Add("appimport $Family|$RegText")
    Test-Path -LiteralPath (Join-Path $script:Users "Packages\$Family\Settings\settings.dat")
}
# stand-ins for the cmdlets the blocks call: nothing stops, opens or waits, and only the test's own files are deleted
function Stop-Process { [CmdletBinding()] param([string[]]$Name, [switch]$Force) foreach ($n in $Name) { $script:Calls.Add("stop $n") } }
function Start-Process { [CmdletBinding()] param([string]$FilePath) $script:Calls.Add("open $FilePath") }
function Start-Sleep { [CmdletBinding()] param([int]$Seconds) $script:Calls.Add("sleep $Seconds") }
function Remove-Item {
    [CmdletBinding()] param([string]$LiteralPath, [switch]$Force)
    if (-not $UserFolder -or -not $LiteralPath.StartsWith($UserFolder, 'OrdinalIgnoreCase')) { throw "not a test file: $LiteralPath" }
    $script:Calls.Add("delete $($LiteralPath.Substring($UserFolder.Length).TrimStart('\'))")
    [IO.File]::Delete($LiteralPath)
}
function Add-Files {
    if (-not $UserFolder) { return }
    foreach ($f in @(Get-ChildItem -LiteralPath $UserFolder -Recurse -File | Sort-Object FullName)) {
        $script:Calls.Add("file $($f.FullName.Substring($UserFolder.Length).TrimStart('\'))|$([IO.File]::ReadAllText($f.FullName))")
    }
}

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
        Add-Files
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
