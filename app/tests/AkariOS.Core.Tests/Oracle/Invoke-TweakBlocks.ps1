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
#   N7: a Prepare block runs too ("Prepare"); "trustedrun <command>" (Run-Trusted; the test's folders as %Root%, a key
#   of the test key as Registry::HKEY_LOCAL_MACHINE\… / HKEY_CURRENT_USER\…), "exe <path>|<args>" (Invoke-AkariExe:
#   0, the test's folders as %Root%), "restorepoint <description>" (New-AkariRestorePoint; -RestoreFails: refused),
#   "readonly <%Root%\…>|<True|False>" (Set-ItemProperty IsReadOnly: done, inside the test's folders only);
#   Get-ChildItem takes -Force; $AkariRoot = -Src (the blocks read OneClick\ files there); -Only 'Apply,…': only
#   those blocks run (a Prepare would empty what the Apply after it needs).
#   N8 (Tools): -Logs: "log <text>" for each Write-Log line; Get-CimInstance answers -Board ('Manufacturer|Product')
#   and -Bios ('Version|yyyy-MM-dd' or 'Version|'), Get-Volume -Volumes ('C|size|free;…'); "clipboard <text>"
#   (Set-Clipboard), "firmware" (Restart-AkariFirmware: -FirmwareCode), "wevtutil <args>" (Invoke-AkariWevtutil; "el"
#   answers -EventLogs 'name;…'), "cleanmgr <set>" (Invoke-AkariCleanMgr), Get-AkariDriverPackages answers -Drivers
#   ('Driver|OriginalFileName|Provider|Class|Version|yyyy-MM-dd;…'), "pnputil <inf>" (Remove-AkariDriverPackage: 0,
#   1 for -DriversKept 'inf;…'), "appx <path>" (Add-AppxPackage), "unzip <archive>|<folder>" (Expand-Archive: done,
#   inside the test's folders only); Remove-AkariPaths, Open-AkariWingetTool and Find-AkariProgram are the real ones
#   (every path given to Remove-AkariPaths must be under -TestDir); Invoke-WebRequest takes -Headers ("+headers" after
#   its line) and, with no -OutFile, records "webtext <uri>" and answers -WebContent and -WebLinks ('href;…');
#   Invoke-AkariExe of 7z.exe "x" copies -Unpack's contents into its -o folder, of any other program records
#   "snap <file>|<text>" for each file under -Snapshot (what an installer finds); Save-AkariFile copies -Downloaded's
#   file ('name=path;…') instead of an empty one; -SystemDrive: $env:SystemDrive (%SystemDrive%\… in the lines);
#   Move-Item takes pipeline input and a folder as -Destination, inside the test's folders.
#   winutil (W1): Invoke-AkariExe answers -ExeCodes ('chkdsk.exe=1;…', by file name, else 0); "wingettool <True|False>"
#   (Install-AkariWingetTool -Force).
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
    [string]$Public = '', [string]$LocalAppData = '', [switch]$MakeFiles, [string]$Value = '', [string]$KeptTasks = '', [switch]$RestoreFails, [string]$Only = '',
    [switch]$Logs, [string]$Board = '', [string]$Bios = '', [string]$Volumes = '', [int]$FirmwareCode = 0, [string]$EventLogs = '', [string]$Drivers = '',
    [string]$DriversKept = '', [string]$TestDir = '', [string]$WebContent = '', [string]$WebLinks = '', [string]$Unpack = '', [string]$Downloaded = '',
    [string]$SystemDrive = '', [string]$Snapshot = '', [string]$ExeCodes = '')
$ErrorActionPreference = 'Stop'
$AkariRoot = $Src
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\Registry.ps1')
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Src 'Core\AppSetup.ps1'), [ref]$null, [ref]$null)
foreach ($fn in 'Get-AkariAppSettingState', 'Uninstall-AkariMsi', 'Invoke-AkariSelfUninstall', 'Remove-AkariStartup', 'Remove-AkariUpdaters', 'Get-AkariWingetExe',
    'Find-AkariProgram', 'Open-AkariWingetTool') {
    . ([scriptblock]::Create($ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true).Extent.Text))
}
$sys = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Src 'Core\System.ps1'), [ref]$null, [ref]$null)
foreach ($fn in 'Remove-AkariScheduledTasks', 'Remove-AkariPaths') {
    . ([scriptblock]::Create($sys.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true).Extent.Text))
}
$script:RealRemovePaths = ${function:Remove-AkariPaths}
function Remove-AkariPaths([string[]]$Paths) {
    foreach ($p in $Paths) { if (-not $TestDir -or -not $p.StartsWith($TestDir, 'OrdinalIgnoreCase')) { throw "not a test path: $p" } }
    & $script:RealRemovePaths $Paths
}
if ($Value) { $AkariValue = $Value }
$script:Calls = [Collections.Generic.List[string]]::new()
function Write-Log([string]$Message) { if ($Logs) { $script:Calls.Add("log $(Format-TestPaths $Message)") } }
function Get-CimInstance {
    [CmdletBinding()] param([string]$ClassName)
    if ($ClassName -eq 'Win32_BaseBoard') { $m, $p = $Board.Split('|', 2); return [pscustomobject]@{ Manufacturer = $m; Product = $p } }
    if ($ClassName -eq 'Win32_BIOS') {
        $v, $d = $Bios.Split('|', 2)
        return [pscustomobject]@{ SMBIOSBIOSVersion = $v; ReleaseDate = $(if ($d) { [datetime]::ParseExact($d, 'yyyy-MM-dd', $null) } else { $null }) }
    }
    throw "no stand-in for $ClassName"
}
function Get-Volume {
    foreach ($v in @($Volumes.Split(';') | Where-Object { $_ })) {
        $l, $s, $f = $v.Split('|')
        [pscustomobject]@{ DriveLetter = [char]$l; Size = [uint64]$s; SizeRemaining = [uint64]$f }
    }
}
function Set-Clipboard { [CmdletBinding()] param([string]$Value) $script:Calls.Add("clipboard $Value") }
function Restart-AkariFirmware { $script:Calls.Add('firmware'); $FirmwareCode }
function Invoke-AkariWevtutil {
    $script:Calls.Add("wevtutil $($args -join ' ')")
    if ($args[0] -eq 'el') { @($EventLogs.Split(';') | Where-Object { $_ }) }
}
function Invoke-AkariCleanMgr([int]$Set) { $script:Calls.Add("cleanmgr $Set") }
function Get-AkariDriverPackages {
    foreach ($d in @($Drivers.Split(';') | Where-Object { $_ })) {
        $n, $o, $p, $c, $v, $t = $d.Split('|')
        [pscustomobject]@{ Driver = $n; OriginalFileName = $o; ProviderName = $p; ClassName = $c; Version = $v; Date = [datetime]::ParseExact($t, 'yyyy-MM-dd', $null) }
    }
}
function Remove-AkariDriverPackage([string]$Inf) { $script:Calls.Add("pnputil $Inf"); if ($Inf -in @($DriversKept.Split(';'))) { 1 } else { 0 } }
function Add-AppxPackage { [CmdletBinding()] param([string]$Path) $script:Calls.Add("appx $(Format-TestPaths $Path)") }
function Expand-Archive {
    [CmdletBinding()] param([string]$LiteralPath, [string]$DestinationPath, [switch]$Force)
    if (-not (Test-InsideTest $LiteralPath) -or -not (Test-InsideTest $DestinationPath)) { throw "not a test path: $LiteralPath" }
    $script:Calls.Add("unzip $(Format-TestPaths $LiteralPath)|$(Format-TestPaths $DestinationPath)")
    # what Expand-Archive -Force does, through .NET (the Archive module calls cmdlets these stand-ins replace)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($LiteralPath)
    try {
        foreach ($e in $zip.Entries) {
            $to = Join-Path $DestinationPath $e.FullName
            [void][IO.Directory]::CreateDirectory((Split-Path $to))
            if ($e.Name) { [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $to, [bool]$Force) }
        }
    } finally { $zip.Dispose() }
}
$script:Users = if ($UserFolder) { $UserFolder } else { Join-Path $env:TEMP "akari-none-$([guid]::NewGuid().ToString('N'))" }
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
    foreach ($r in @(@('SystemRoot', $SystemRoot), @('ProgramFiles', $ProgramFiles), @('ProgramFiles(x86)', $ProgramFilesX86), @('ProgramData', $ProgramData), @('PUBLIC', $Public), @('SystemDrive', $SystemDrive))) {
        $root = "$($r[1])".TrimEnd('\')
        if ($root -and ($Path -eq $root -or $Path.StartsWith("$root\", 'OrdinalIgnoreCase'))) { return "%$($r[0])%$($Path.Substring($root.Length))" }
    }
    $null
}
function Format-TestPaths([string]$Text) {
    foreach ($r in @(@('SystemRoot', $SystemRoot), @('ProgramFiles(x86)', $ProgramFilesX86), @('ProgramFiles', $ProgramFiles), @('ProgramData', $ProgramData), @('PUBLIC', $Public), @('SystemDrive', $SystemDrive))) {
        if ($r[1]) { $Text = $Text.Replace("$($r[1])".TrimEnd('\'), "%$($r[0])%") }
    }
    $Text
}
function takeown.exe { $script:Calls.Add("takeown $(Format-TestPaths ($args -join ' '))") }
function icacls.exe { $script:Calls.Add("icacls $(Format-TestPaths ($args -join ' '))") }
# HKLM: / HKCU: paths read on the test key
function Test-Path {
    [CmdletBinding()] param([Parameter(Position = 0, ValueFromPipeline)][string]$Path, [string]$LiteralPath, [string]$PathType = 'Any')
    $p = if ($LiteralPath) { $LiteralPath } else { $Path }
    if ($p -match '^(HKLM|HKCU):\\') { return Microsoft.PowerShell.Management\Test-Path -LiteralPath (Resolve-AkariRegPath $p) }
    if ($LiteralPath) { Microsoft.PowerShell.Management\Test-Path -LiteralPath $p -PathType $PathType } else { Microsoft.PowerShell.Management\Test-Path -Path $p -PathType $PathType }
}
function Get-ChildItem {
    [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Path, [string[]]$LiteralPath, [string]$Filter, [switch]$Recurse, [switch]$File, [switch]$Directory, [int]$Depth, [switch]$Force)
    $a = @{}
    if ($PSBoundParameters.ContainsKey('Depth')) { $a.Depth = $Depth }
    $redirect = { param($x) if ($x -match '^(HKLM|HKCU):\\') { Resolve-AkariRegPath $x } else { $x } }
    if ($LiteralPath) { $a.LiteralPath = @($LiteralPath | ForEach-Object { & $redirect $_ }) } else { $a.Path = @($Path | ForEach-Object { & $redirect $_ }) }
    if ($Filter) { $a.Filter = $Filter }
    foreach ($k in 'Recurse', 'File', 'Directory', 'Force') { if ($PSBoundParameters[$k]) { $a[$k] = $true } }
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
    $p = Get-TestFilePath $Path
    if (-not $p) { throw "not a test path: $Path" }
    $script:Calls.Add("own $p")
}
function Move-Item {
    [CmdletBinding()] param([Parameter(ValueFromPipelineByPropertyName)][Alias('PSPath')][string]$LiteralPath, [string]$Destination, [switch]$Force)
    process {
        $src = $LiteralPath -replace '^Microsoft\.PowerShell\.Core\\(FileSystem::)?', ''
        $from = Get-TestFilePath $src; $to = Get-TestFilePath $Destination
        if (-not $from -or -not $to) { throw "not a test path: $src" }
        $script:Calls.Add("move $from|$to")
        # into a folder that is there (Move-Item's own rule)
        $target = if ([IO.Directory]::Exists($Destination)) { Join-Path $Destination (Split-Path $src -Leaf) } else { $Destination }
        if ($Force -and [IO.File]::Exists($target)) { [IO.File]::Delete($target) }
        if ([IO.Directory]::Exists($src)) { [IO.Directory]::Move($src, $target) } else { [IO.File]::Move($src, $target) }
    }
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
    foreach ($p in @(@($LiteralPath) + @($Path) | Where-Object { $_ } | ForEach-Object { $_ -replace '^Microsoft\.PowerShell\.Core\\(FileSystem::)?', '' })) {
        if ($key = Get-TestKeyPath $p) { $script:Calls.Add("delkey $key"); continue }
        if ($p -match '^(HKLM|HKCU):\\') { $script:Calls.Add("delkey $p"); continue }
        if ($UserFolder -and $p.StartsWith($UserFolder, 'OrdinalIgnoreCase')) {
            $script:Calls.Add("delete $($p.Substring($UserFolder.Length).TrimStart('\'))")
            if ([IO.Directory]::Exists($p)) { [IO.Directory]::Delete($p, $true) } else { [IO.File]::Delete($p) }
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
    [CmdletBinding()] param([Parameter(Position = 0)][string]$Path, [string]$LiteralPath, [Parameter(Position = 1)][string]$Destination, [switch]$Recurse, [switch]$Force)
    if (-not (Test-InsideTest $Destination)) { throw "not a test path: $Destination" }
    if ($LiteralPath) { Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Recurse:$Recurse -Force:$Force }
    else { Microsoft.PowerShell.Management\Copy-Item -Path $Path -Destination $Destination -Recurse:$Recurse -Force:$Force }
}
function Invoke-WebRequest {
    [CmdletBinding()] param([Parameter(Position = 0)][string]$Uri, [string]$OutFile, [switch]$UseBasicParsing, [hashtable]$Headers)
    $h = if ($Headers) { ' +headers' } else { '' }
    if (-not $OutFile) {
        $script:Calls.Add("webtext $Uri$h")
        return [pscustomobject]@{ Content = $WebContent; Links = @($WebLinks.Split(';') | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ href = $_ } }) }
    }
    if (-not (Test-InsideTest $OutFile)) { throw "not a test path: $OutFile" }
    $script:Calls.Add("web $Uri|$OutFile$h")
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
# winget's own repair (tools-fix-winget): recorded
function Install-AkariWingetTool([switch]$Force) { $script:Calls.Add("wingettool $([bool]$Force)") }
function Save-AkariFile([string]$Name, [string]$OutFile) {
    $script:Calls.Add("download $Name|$OutFile")
    if ($MakeFiles -and (Get-TestFilePath $OutFile)) {
        [void][IO.Directory]::CreateDirectory((Split-Path $OutFile))
        $from = @($Downloaded.Split(';') | Where-Object { $_ -like "$Name=*" } | ForEach-Object { $_.Split('=', 2)[1] }) | Select-Object -First 1
        if ($from) { [IO.File]::Copy($from, $OutFile, $true) } else { [IO.File]::WriteAllText($OutFile, '') }
    }
    $OutFile
}
function New-AkariShortcut([string]$Name, [string]$Target) {
    $script:Calls.Add("shortcut $Name|$Target")
    if ($MakeFiles -and $ProgramData) {
        $lnk = "$ProgramData\Microsoft\Windows\Start Menu\Programs\$Name.lnk"
        [void][IO.Directory]::CreateDirectory((Split-Path $lnk)); [IO.File]::WriteAllText($lnk, '')
    }
}
function Run-Trusted([string]$Command) {
    $c = Format-TestPaths $Command
    if ($TestRoot) {
        foreach ($h in @(@('HKLM', 'HKEY_LOCAL_MACHINE'), @('HKCU', 'HKEY_CURRENT_USER'))) { $c = $c.Replace("HKEY_CURRENT_USER\$TestRoot\$($h[0])\", "$($h[1])\") }
    }
    $script:Calls.Add("trustedrun $c")
}
function Invoke-AkariExe([string]$Path, [string[]]$Arguments) {
    $script:Calls.Add("exe $(Format-TestPaths $Path)|$(Format-TestPaths ($Arguments -join ' '))")
    # 7-Zip "x <archive> -o<folder>": -Unpack's contents land there
    if ($Unpack -and (Split-Path $Path -Leaf) -eq '7z.exe' -and $Arguments[0] -eq 'x') {
        $to = ($Arguments | Where-Object { $_ -like '-o*' } | Select-Object -First 1).Substring(2)
        if (-not (Test-InsideTest $to)) { throw "not a test path: $to" }
        [void][IO.Directory]::CreateDirectory($to)
        Microsoft.PowerShell.Management\Copy-Item -Path (Join-Path $Unpack '*') -Destination $to -Recurse -Force
    }
    # -Snapshot: the folder's files as the program found them ("snap <%Root%\file>|<text>")
    if ($Snapshot -and (Split-Path $Path -Leaf) -ne '7z.exe' -and [IO.Directory]::Exists($Snapshot)) {
        foreach ($f in @(Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $Snapshot -Recurse -File | Sort-Object FullName)) {
            $script:Calls.Add("snap $(Format-TestPaths $f.FullName)|$([IO.File]::ReadAllText($f.FullName))")
        }
    }
    # -ExeCodes ('chkdsk.exe=1;…'): a program's exit code by its file name, else 0
    $code = @($ExeCodes.Split(';') | Where-Object { $_ -like "$(Split-Path $Path -Leaf)=*" } | ForEach-Object { [int]$_.Split('=', 2)[1] }) | Select-Object -First 1
    if ($code) { $code } else { 0 }
}
function New-AkariRestorePoint([string]$Description = 'AkariOS') {
    $script:Calls.Add("restorepoint $Description")
    if ($RestoreFails) { @{ Ok = $false; Message = 'Windows refused the restore point' } } else { @{ Ok = $true; Message = '' } }
}
function Set-ItemProperty {
    [CmdletBinding()] param([string]$LiteralPath, [string]$Name, $Value)
    $r = Get-TestFilePath $LiteralPath
    if (-not $r -or $Name -ne 'IsReadOnly') { throw "not a test file: $LiteralPath $Name" }
    $script:Calls.Add("readonly $r|$([bool]$Value)")
    Microsoft.PowerShell.Management\Set-ItemProperty -LiteralPath $LiteralPath -Name IsReadOnly -Value ([bool]$Value)
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
if ($SystemDrive) { $env:SystemDrive = $SystemDrive.TrimEnd('\') }
$env:PUBLIC = if ($Public) { $Public } else { $none }
$env:LOCALAPPDATA = if ($LocalAppData) { $LocalAppData } else { $none }
$result = [ordered]@{}
foreach ($id in @($Ids.Split(',') | Where-Object { $_ })) {
    $t = $tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    $AkariTweakDir = Split-Path $t.Source
    $entry = [ordered]@{}
    foreach ($b in 'Detect', 'Value', 'Before', 'Prepare', 'Apply', 'Revert') {
        if (-not $t.$b -or ($Only -and $b -notin $Only.Split(','))) { continue }
        $script:Calls.Clear()
        # a block that throws (a tool missing): its message is its last line; a stand-in called wrongly still fails the run
        try { $said = & $t.$b }
        catch {
            if ($_.Exception -is [Management.Automation.ParameterBindingException] -or $_.Exception -is [Management.Automation.CommandNotFoundException]) { throw }
            $script:Calls.Add("throw $($_.Exception.Message)"); $said = $null
        }
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
