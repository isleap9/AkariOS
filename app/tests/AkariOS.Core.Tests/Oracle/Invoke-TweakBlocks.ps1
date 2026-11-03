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
#   "open <target>" (Start-Process), "run <target>|<arguments>" (Start-Process -ArgumentList), "sleep <seconds>",
#   "delete <path under -UserFolder>" (Remove-Item), "delkey <path>" / "newkey <path>" (Remove-Item / New-Item of a
#   key under -TestRoot, written back as HKCU:\ / HKLM:\; nothing is changed), "download <name>|<out file>"
#   (Save-AkariFile), "shortcut <name>|<target>" (New-AkariShortcut), "unblock <path under -ProgramData>"
#   (Unblock-File), "remembered <id>" / "remember <id> <True|False>" (Get- / Set-AkariRememberedState),
#   "mmagent enable|disable <feature>" / "mmagent set MaxOperationAPIFiles <n>" (Enable- / Disable- / Set-MMAgent),
#   "task <path>|<name>|<True|False>" (Set-AkariScheduledTask), "stopservice <name>" / "startservice <name>",
#   "own <path>" (Grant-AkariOwnership) and "move <from>|<to>" (Move-Item: done, inside -SystemRoot only), paths
#   under -SystemRoot written as %SystemRoot%\…, "sleepms <n>", and with -UserFolder, after each block,
#   "file <path under it>|<text>" for every file there.
# Get-MMAgent answers -MMAgent ('ApplicationLaunchPrefetching=True;…;MaxOperationAPIFiles=512'). -SystemRoot: the
# blocks' $env:SystemRoot (a temp folder the C# test laid out).
# Get-AkariGpus answers -Gpus ('Vendor|Path;…'), Get-AkariGpuDevices -GpuDevices ('id;…'), Get-AkariRememberedState
# -Remembered ('true' = Applied). -ProgramFiles, -ProgramFilesX86, -ProgramData: the blocks' $env: folders (temp
# folders the C# test filled), set once the Tweaks are loaded.
# Answers: powercfg /list with -PlanList (one GUID per line, as powercfg prints them), Read-AkariBcd with -BcdLines
# ('|'-separated), Read-AkariAppSettings with -AppValues ('Key\Name=hex;…' for every family, 'held' = $null);
# Get-AkariAppSettingState is the real one (only that function is read out of Core\AppSetup.ps1). Only the blocks of
# the Ids run, so a Tweak whose blocks call anything else (Stop-Service…) is never listed. -TestRoot:
# Resolve-AkariRegPath points every hive at HKCU\<it>\<hive> (a test key the C# test filled), so a block's
# Get-ChildItem reads the test key, never the real hives. -UserFolder: Get-AkariUserFolder's answer for every name (a
# temp folder the C# test filled; without it, a folder that doesn't exist).
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [string]$Ids = '', [string]$PlanList = '',
    [string]$BcdLines = '', [string]$TestRoot = '', [string]$AppValues = '', [string]$UserFolder = '', [string]$Gpus = '',
    [string]$GpuDevices = '', [string]$Remembered = '', [string]$ProgramFiles = '', [string]$ProgramFilesX86 = '', [string]$ProgramData = '',
    [string]$MMAgent = '', [string]$SystemRoot = '')
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
function Start-Process {
    [CmdletBinding()] param([string]$FilePath, [string[]]$ArgumentList, [switch]$Wait)
    if ($ArgumentList) { $script:Calls.Add("run $FilePath|$($ArgumentList -join ' ')") } else { $script:Calls.Add("open $FilePath") }
}
function Start-Sleep {
    [CmdletBinding()] param([int]$Seconds, [int]$Milliseconds)
    if ($Milliseconds) { $script:Calls.Add("sleepms $Milliseconds") } else { $script:Calls.Add("sleep $Seconds") }
}
function Stop-Service { [CmdletBinding()] param([string]$Name, [switch]$Force) $script:Calls.Add("stopservice $Name") }
function Start-Service { [CmdletBinding()] param([string]$Name) $script:Calls.Add("startservice $Name") }
function Set-AkariScheduledTask([string]$TaskPath, [string]$TaskName, [bool]$Enabled) { $script:Calls.Add("task $TaskPath|$TaskName|$Enabled"); $true }
# a path under -SystemRoot as %SystemRoot%\…, else $null
function Get-RootPath([string]$Path) {
    if (-not $SystemRoot -or -not $Path.StartsWith($SystemRoot, 'OrdinalIgnoreCase')) { return $null }
    "%SystemRoot%$($Path.Substring($SystemRoot.TrimEnd('\').Length))"
}
function Grant-AkariOwnership([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $p = Get-RootPath $Path
    if (-not $p) { throw "not a test path: $Path" }
    $script:Calls.Add("own $p")
}
function Move-Item {
    [CmdletBinding()] param([string]$LiteralPath, [string]$Destination, [switch]$Force)
    $from = Get-RootPath $LiteralPath; $to = Get-RootPath $Destination
    if (-not $from -or -not $to) { throw "not a test path: $LiteralPath" }
    $script:Calls.Add("move $from|$to")
    if ([IO.Directory]::Exists($LiteralPath)) { [IO.Directory]::Move($LiteralPath, $Destination) } else { [IO.File]::Move($LiteralPath, $Destination) }
}
function Get-MMAgent {
    $o = [ordered]@{}
    foreach ($p in @($MMAgent.Split(';') | Where-Object { $_ })) {
        $k, $v = $p.Split('=', 2)
        $o[$k] = if ($v -in 'True', 'False') { $v -eq 'True' } else { [uint32]$v }
    }
    [pscustomobject]$o
}
function Write-MMAgentCall([string]$Verb, [hashtable]$Bound) {
    foreach ($k in @($Bound.Keys | Where-Object { $_ -notin 'ErrorAction' })) { $script:Calls.Add("mmagent $Verb $k") }
}
function Enable-MMAgent {
    [CmdletBinding()] param([switch]$ApplicationLaunchPrefetching, [switch]$ApplicationPreLaunch, [switch]$OperationAPI, [switch]$PageCombining, [switch]$MemoryCompression)
    Write-MMAgentCall 'enable' $PSBoundParameters
}
function Disable-MMAgent {
    [CmdletBinding()] param([switch]$ApplicationLaunchPrefetching, [switch]$ApplicationPreLaunch, [switch]$OperationAPI, [switch]$PageCombining, [switch]$MemoryCompression)
    Write-MMAgentCall 'disable' $PSBoundParameters
}
function Set-MMAgent { [CmdletBinding()] param([uint32]$MaxOperationAPIFiles) $script:Calls.Add("mmagent set MaxOperationAPIFiles $MaxOperationAPIFiles") }
# a key under -TestRoot as the block named it (HKCU:\… / HKLM:\…), else $null
function Get-TestKeyPath([string]$Path) {
    if (-not $TestRoot) { return $null }
    $root = "Registry::HKEY_CURRENT_USER\$TestRoot\"
    if (-not $Path.StartsWith($root, 'OrdinalIgnoreCase')) { return $null }
    $hive, $rest = $Path.Substring($root.Length).Split('\', 2)
    "$($hive):\$rest"
}
function Remove-Item {
    [CmdletBinding()] param([string]$LiteralPath, [switch]$Recurse, [switch]$Force)
    if ($key = Get-TestKeyPath $LiteralPath) { $script:Calls.Add("delkey $key"); return }
    if (-not $UserFolder -or -not $LiteralPath.StartsWith($UserFolder, 'OrdinalIgnoreCase')) { throw "not a test file: $LiteralPath" }
    $script:Calls.Add("delete $($LiteralPath.Substring($UserFolder.Length).TrimStart('\'))")
    [IO.File]::Delete($LiteralPath)
}
function New-Item {
    [CmdletBinding()] param([string]$Path, [switch]$Force)
    if ($key = Get-TestKeyPath $Path) { $script:Calls.Add("newkey $key"); return }
    throw "not a test key: $Path"
}
function Unblock-File {
    [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject)
    process { $script:Calls.Add("unblock $($InputObject.FullName.Substring($ProgramData.Length).TrimStart('\'))") }
}
function Save-AkariFile([string]$Name, [string]$OutFile) { $script:Calls.Add("download $Name|$OutFile"); $OutFile }
function New-AkariShortcut([string]$Name, [string]$Target) { $script:Calls.Add("shortcut $Name|$Target") }
function Get-AkariRememberedState([string]$Id) { $script:Calls.Add("remembered $Id"); $Remembered -eq 'true' }
function Set-AkariRememberedState([string]$Id, [bool]$Applied) { $script:Calls.Add("remember $Id $Applied") }
function Get-AkariGpus {
    foreach ($g in @($Gpus.Split(';') | Where-Object { $_ })) { $v, $p = $g.Split('|', 2); [pscustomobject]@{ Path = $p; Name = ''; Vendor = $v } }
}
function Get-AkariGpuDevices { @($GpuDevices.Split(';') | Where-Object { $_ }) }
function Add-Files {
    if (-not $UserFolder) { return }
    foreach ($f in @(Get-ChildItem -LiteralPath $UserFolder -Recurse -File | Sort-Object FullName)) {
        $script:Calls.Add("file $($f.FullName.Substring($UserFolder.Length).TrimStart('\'))|$([IO.File]::ReadAllText($f.FullName))")
    }
}

$root = Join-Path $Src 'Tweaks'
$tweaks = (Get-AkariTweaks $root).Tweaks
# the blocks' folders: the C# test's temp ones (never the real ones: the blocks look for files there)
$none = Join-Path $env:TEMP "akari-none-$([guid]::NewGuid().ToString('N'))"
$env:ProgramFiles = if ($ProgramFiles) { $ProgramFiles } else { $none }
${env:ProgramFiles(x86)} = if ($ProgramFilesX86) { $ProgramFilesX86 } else { $none }
$env:ProgramData = if ($ProgramData) { $ProgramData } else { $none }
if ($SystemRoot) { $env:SystemRoot = $SystemRoot }
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
