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
#   N5b (the legacy app removals): "delservice <name>" (Remove-AkariService), "unregister <TaskPath>|<TaskName>"
#   (Unregister-ScheduledTask), "takeown <args>" / "icacls <args>", "delkey HKLM:\…" (Remove-Item of an HKLM: / HKCU:
#   key: recorded, never done), "delete %Root%\…" / "newfile %Root%\…" (Remove-Item / New-Item -ItemType File under
#   -SystemRoot, -ProgramFiles, -ProgramFilesX86, -ProgramData, -Public: done in those test copies, recorded only when
#   the item was there). Get-Service answers -Services ('name;…'), Get-Process -Processes ('name;…', each with a
#   window), Get-ScheduledTask -Tasks ('\path\|name;…'); Get-AkariMsi reads the uninstall keys of the test key; HKLM: /
#   HKCU: paths given to Test-Path, Get-ChildItem and Get-AkariRegValue are read on the test key; Uninstall-AkariMsi and
#   Invoke-AkariSelfUninstall are the real ones (read out of Core\AppSetup.ps1).
#   N5c (the installs): a Before block runs too ("Before"); Remove-AkariStartup, Remove-AkariUpdaters and
#   Get-AkariWingetExe are the real ones; "wait <process>|<timeout>" (Wait-Process), "web <url>|<out file>"
#   (Invoke-WebRequest: an empty file made), with -MakeFiles (a test whose two sides have their own folders)
#   Save-AkariFile and New-AkariShortcut also make an empty file (the out file, the Start menu .lnk under -ProgramData)
#   inside the test's folders; Copy-Item and New-Item -ItemType Directory are
#   done inside the test's folders or -UserFolder only; Remove-Item takes pipeline input (a registry key's PSPath).
#   -Processes entries may carry a path ('name=path;…', Get-Process's Path); -LocalAppData: the blocks'
#   $env:LOCALAPPDATA (portable winget packages).
#   N6: a Choice's Value block runs too ("Value": its "result <value>"); -Value: $AkariValue for Apply; the real
#   Remove-AkariScheduledTasks (read out of Core\System.ps1) on Get-ScheduledTask's answers; -KeptTasks ('name;…'):
#   tasks Unregister-ScheduledTask refuses (it throws for them, as Windows' protected ones).
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
    [string]$MMAgent = '', [string]$SystemRoot = '', [string]$Services = '', [string]$Processes = '', [string]$Tasks = '',
    [string]$Public = '', [string]$LocalAppData = '', [switch]$MakeFiles, [string]$Value = '', [string]$KeptTasks = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\Registry.ps1')
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Src 'Core\AppSetup.ps1'), [ref]$null, [ref]$null)
foreach ($fn in 'Get-AkariAppSettingState', 'Uninstall-AkariMsi', 'Invoke-AkariSelfUninstall', 'Remove-AkariStartup', 'Remove-AkariUpdaters', 'Get-AkariWingetExe') {
    . ([scriptblock]::Create($ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true).Extent.Text))
}
$sys = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Src 'Core\System.ps1'), [ref]$null, [ref]$null)
. ([scriptblock]::Create($sys.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Remove-AkariScheduledTasks' }, $true).Extent.Text))
if ($Value) { $AkariValue = $Value }
function Write-Log { }
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
function Stop-Process {
    [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Name, [Parameter(ValueFromPipeline)]$InputObject, [switch]$Force)
    process { if ($InputObject) { $script:Calls.Add("stop $($InputObject.ProcessName)") } else { foreach ($n in $Name) { $script:Calls.Add("stop $n") } } }
}
function Get-Process {
    [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Name)
    foreach ($e in @($Processes.Split(';') | Where-Object { $_ })) {
        $p, $path = $e.Split('=', 2)
        if (-not $Name -or $p -in $Name) { [pscustomobject]@{ ProcessName = $p; Name = $p; MainWindowHandle = 1; Path = $path } }
    }
}
function Wait-Process {
    [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, [int]$Timeout)
    process { $script:Calls.Add("wait $($InputObject.ProcessName)|$Timeout") }
}
function Get-Service {
    [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Name)
    foreach ($s in @($Services.Split(';') | Where-Object { $_ })) { if (-not $Name -or $s -in $Name) { [pscustomobject]@{ Name = $s } } }
}
function Remove-AkariService([string]$Name) { $script:Calls.Add("delservice $Name") }
function Get-ScheduledTask {
    [CmdletBinding()] param([string]$TaskPath)
    foreach ($t in @($Tasks.Split(';') | Where-Object { $_ })) { $p, $n = $t.Split('|', 2); [pscustomobject]@{ TaskPath = $p; TaskName = $n } }
}
function Unregister-ScheduledTask {
    [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, [string]$TaskName, [switch]$Confirm)
    process {
        $found = if ($InputObject) { @($InputObject) } else { @(Get-ScheduledTask | Where-Object { $_.TaskName -eq $TaskName }) }
        foreach ($t in $found) {
            if ($t.TaskName -in @($KeptTasks.Split(';'))) { throw "Access is denied: $($t.TaskName)" }
            $script:Calls.Add("unregister $($t.TaskPath)|$($t.TaskName)")
        }
    }
}
# the uninstall keys of the test key (Get-AkariMsi reads the real ones)
function Get-AkariMsi([string]$Name) {
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($s in @(Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath (Resolve-AkariRegPath $k) -ErrorAction SilentlyContinue)) {
            $d = (Microsoft.PowerShell.Management\Get-ItemProperty -LiteralPath $s.PSPath -ErrorAction SilentlyContinue).DisplayName
            if ($d -like $Name) { [pscustomobject]@{ Name = $d; Code = $s.PSChildName } }
        }
    }
}
# a path under one of the test's folders as %Root%\…, else $null
function Get-TestFilePath([string]$Path) {
    foreach ($r in @(@('SystemRoot', $SystemRoot), @('ProgramFiles', $ProgramFiles), @('ProgramFiles(x86)', $ProgramFilesX86), @('ProgramData', $ProgramData), @('PUBLIC', $Public))) {
        $root = "$($r[1])".TrimEnd('\')
        if ($root -and ($Path -eq $root -or $Path.StartsWith("$root\", 'OrdinalIgnoreCase'))) { return "%$($r[0])%$($Path.Substring($root.Length))" }
    }
    $null
}
function Format-TestPaths([string]$Text) {
    foreach ($r in @(@('SystemRoot', $SystemRoot), @('ProgramFiles(x86)', $ProgramFilesX86), @('ProgramFiles', $ProgramFiles), @('ProgramData', $ProgramData), @('PUBLIC', $Public))) {
        if ($r[1]) { $Text = $Text.Replace("$($r[1])".TrimEnd('\'), "%$($r[0])%") }
    }
    $Text
}
function takeown.exe { $script:Calls.Add("takeown $(Format-TestPaths ($args -join ' '))") }
function icacls.exe { $script:Calls.Add("icacls $(Format-TestPaths ($args -join ' '))") }
# HKLM: / HKCU: paths read on the test key
function Test-Path {
    [CmdletBinding()] param([Parameter(Position = 0)][string]$Path, [string]$LiteralPath)
    $p = if ($LiteralPath) { $LiteralPath } else { $Path }
    if ($p -match '^(HKLM|HKCU):\\') { return Microsoft.PowerShell.Management\Test-Path -LiteralPath (Resolve-AkariRegPath $p) }
    if ($LiteralPath) { Microsoft.PowerShell.Management\Test-Path -LiteralPath $p } else { Microsoft.PowerShell.Management\Test-Path -Path $p }
}
function Get-ChildItem {
    [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Path, [string[]]$LiteralPath, [string]$Filter, [switch]$Recurse, [switch]$File, [switch]$Directory, [int]$Depth)
    $a = @{}
    if ($PSBoundParameters.ContainsKey('Depth')) { $a.Depth = $Depth }
    $redirect = { param($x) if ($x -match '^(HKLM|HKCU):\\') { Resolve-AkariRegPath $x } else { $x } }
    if ($LiteralPath) { $a.LiteralPath = @($LiteralPath | ForEach-Object { & $redirect $_ }) } else { $a.Path = @($Path | ForEach-Object { & $redirect $_ }) }
    if ($Filter) { $a.Filter = $Filter }
    foreach ($k in 'Recurse', 'File', 'Directory') { if ($PSBoundParameters[$k]) { $a[$k] = $true } }
    if ($PSBoundParameters.ContainsKey('ErrorAction')) { $a.ErrorAction = $PSBoundParameters['ErrorAction'] }
    Microsoft.PowerShell.Management\Get-ChildItem @a
}
$script:RealRegValue = ${function:Get-AkariRegValue}
function Get-AkariRegValue([string]$Path, [string]$Name) {
    $p = if ($Path -match '^(HKLM|HKCU):\\') { Resolve-AkariRegPath $Path } else { $Path }
    & $script:RealRegValue $p $Name
}
function Start-Process {
    [CmdletBinding()] param([string]$FilePath, [string[]]$ArgumentList, [switch]$Wait, [string]$WindowStyle, [switch]$NoNewWindow)
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
    [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Path, [Parameter(ValueFromPipelineByPropertyName)][Alias('PSPath')][string[]]$LiteralPath, [switch]$Recurse, [switch]$Force)
    process {
    foreach ($p in @(@($LiteralPath) + @($Path) | Where-Object { $_ } | ForEach-Object { $_ -replace '^Microsoft\.PowerShell\.Core\\', '' })) {
        if ($key = Get-TestKeyPath $p) { $script:Calls.Add("delkey $key"); continue }
        if ($p -match '^(HKLM|HKCU):\\') { $script:Calls.Add("delkey $p"); continue }
        if ($UserFolder -and $p.StartsWith($UserFolder, 'OrdinalIgnoreCase')) {
            $script:Calls.Add("delete $($p.Substring($UserFolder.Length).TrimStart('\'))")
            [IO.File]::Delete($p)
            continue
        }
        $r = Get-TestFilePath $p
        if (-not $r) { throw "not a test file: $p" }
        if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $p) {
            $script:Calls.Add("delete $r")
            Microsoft.PowerShell.Management\Remove-Item -LiteralPath $p -Recurse -Force
        }
    }
    }
}
# a path inside the test's folders, -UserFolder or -LocalAppData
function Test-InsideTest([string]$Path) {
    if (Get-TestFilePath $Path) { return $true }
    foreach ($r in $UserFolder, $LocalAppData) { if ($r -and $Path.StartsWith($r, 'OrdinalIgnoreCase')) { return $true } }
    $false
}
function Copy-Item {
    [CmdletBinding()] param([Parameter(Position = 0)][string]$Path, [Parameter(Position = 1)][string]$Destination, [switch]$Recurse, [switch]$Force)
    if (-not (Test-InsideTest $Destination)) { throw "not a test path: $Destination" }
    Microsoft.PowerShell.Management\Copy-Item -Path $Path -Destination $Destination -Recurse:$Recurse -Force:$Force
}
function Invoke-WebRequest {
    [CmdletBinding()] param([Parameter(Position = 0)][string]$Uri, [string]$OutFile, [switch]$UseBasicParsing)
    if (-not (Test-InsideTest $OutFile)) { throw "not a test path: $OutFile" }
    $script:Calls.Add("web $Uri|$OutFile")
    [IO.File]::WriteAllText($OutFile, '')
}
function New-Item {
    [CmdletBinding()] param([Parameter(Position = 0)][string]$Path, [string]$ItemType, [switch]$Force)
    if ($key = Get-TestKeyPath $Path) { $script:Calls.Add("newkey $key"); return }
    if ($ItemType -eq 'Directory' -and (Test-InsideTest $Path)) { [void][IO.Directory]::CreateDirectory($Path); return }
    $r = Get-TestFilePath $Path
    if ($r -and $ItemType -eq 'File') {
        Microsoft.PowerShell.Management\New-Item -Path $Path -ItemType File -Force | Out-Null
        $script:Calls.Add("newfile $r")
        return
    }
    throw "not a test key: $Path"
}
function Unblock-File {
    [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject)
    process { $script:Calls.Add("unblock $($InputObject.FullName.Substring($ProgramData.Length).TrimStart('\'))") }
}
# a Winget Tweak's Detect (the Loader's): never installed here
function Test-AkariWingetInstalled([string]$Id, [string]$Source = 'winget') { $false }
# its Apply (the Loader's: Before, the install, After): the install recorded
function Install-AkariWingetPackage([string]$Id, [string]$Source = 'winget') { $script:Calls.Add("winget $Id $Source") }
function Save-AkariFile([string]$Name, [string]$OutFile) {
    $script:Calls.Add("download $Name|$OutFile")
    if ($MakeFiles -and (Get-TestFilePath $OutFile)) { [void][IO.Directory]::CreateDirectory((Split-Path $OutFile)); [IO.File]::WriteAllText($OutFile, '') }
    $OutFile
}
function New-AkariShortcut([string]$Name, [string]$Target) {
    $script:Calls.Add("shortcut $Name|$Target")
    if ($MakeFiles -and $ProgramData) {
        $lnk = "$ProgramData\Microsoft\Windows\Start Menu\Programs\$Name.lnk"
        [void][IO.Directory]::CreateDirectory((Split-Path $lnk)); [IO.File]::WriteAllText($lnk, '')
    }
}
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
$env:PUBLIC = if ($Public) { $Public } else { $none }
$env:LOCALAPPDATA = if ($LocalAppData) { $LocalAppData } else { $none }
$result = [ordered]@{}
foreach ($id in @($Ids.Split(',') | Where-Object { $_ })) {
    $t = $tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    $AkariTweakDir = Split-Path $t.Source
    $entry = [ordered]@{}
    foreach ($b in 'Detect', 'Value', 'Before', 'Apply', 'Revert') {
        if (-not $t.$b) { continue }
        $script:Calls.Clear()
        $said = & $t.$b
        if ($b -in 'Detect', 'Value') { $script:Calls.Add("result $said") }
        elseif ($b -eq 'Apply' -and $said) { $script:Calls.Add("said $(@($said) -join ' / ')") }
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
