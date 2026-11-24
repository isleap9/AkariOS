# The reference for the native IsoBuild (app/AkariOS.Core/Iso/IsoBuild.cs): src\Core\Iso.ps1's real
# Open-AkariIsoSource, Mount-AkariIsoEdition, Invoke-AkariIsoBuild and Clear-AkariIsoLeftover, with every wrapper that
# reaches the system replaced by a recorder answering the case (-Case, a JSON file IsoBuildOracleTests writes). Files
# only under -Root (the C# test's temp folder: the "ISO drive" at <root>\drive, the output at <root>\out), the image's
# hives on -Reg (the test key's HKLM\AkariIso_ prefix, HKCU:\Software\AkariTest\<guid>\HKLM\AkariIso_), the marker in
# <root>\iso-mount.json. Nothing real is mounted, loaded or run.
# Case: Actions (Open, Mount, Build, Leftover, in order), Drive @{ Free; Format }, Wims @{ '<root>\...wim' = images },
# ImageFiles / BootFiles (made under the mount when install.wim / boot.wim is mounted), ImageApps @{ Name; Package },
# ImageFeatures (names; one DISM disabled reads back DisabledWithPayloadRemoved, but StuckFeatures), DismCodes
# @{ verb = exit code }, Fail (Mount | Trusted | Oscdimg), Denied (hive paths an admin can't change: rows and keys
# under them throw unless written as TrustedInstaller), Marker (left at the start), Choices @{ Index; Edition;
# Apps; Features; Capabilities; Packages; AkariOS (bool); Unattend (text); Settings (the native
# IsoBuildSettings: Compression; Turbo; CleanLeftovers; LeaveOutNetFx3Files); the wizard's Groups, AppPatterns,
# FirstSignIn (bool), ImageBuild, Bake (@{ Id; Value }: the real Tweaks, loaded then) }. ImageCapabilities @{ Name;
# State }: the image's capabilities.
# Writes @{ Calls; Log; ErrLog; Progress; Ops; Results; Marker } as JSON to -Out; paths start <root>. Ops = each
# operation the build reports ('<stage index>|<name>|<state>|<note>'); its report.json is left in <root>\out.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Case,
    [Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Reg)
$ErrorActionPreference = 'Stop'
if ($Reg -notlike 'HKCU:\Software\AkariTest\*') { throw "not a test key: $Reg" }
# $script:CaseData in the recorders: Invoke-AkariIsoBuild has a $c of its own (exit codes)
$c = [IO.File]::ReadAllText($Case).Replace('<root>', $Root.Replace('\', '\\')) | ConvertFrom-Json
$script:CaseData = $c
$AkariIsoMarker = Join-Path $Root 'iso-mount.json'
$AkariIsoRegRoot = $Reg
foreach ($f in 'Log', 'Version', 'Registry', 'Trusted', 'AppSetup', 'System', 'Runner', 'Loader', 'Iso') { . (Join-Path $Src "Core\$f.ps1") }

$script:Calls = [Collections.Generic.List[string]]::new()
$script:Log = [Collections.Generic.List[string]]::new()
$script:ErrLog = [Collections.Generic.List[string]]::new()
$script:Progress = [Collections.Generic.List[string]]::new()
$script:Ops = [Collections.Generic.List[string]]::new()
$script:InTrusted = $false
$script:Denied = @($c.Denied | Where-Object { $_ })
$script:Disabled = @{}

# the script's own roots ($Root alone would be the caller's: Open-AkariIsoSource has a $root of its own)
$script:TestRoot = $Root
$script:TestReg = $Reg
function Norm([string]$s) { $s.Replace($script:TestReg, 'HKLM:\AkariIso_').Replace($script:TestRoot, '<root>') }
function Rec([string]$s) { $script:Calls.Add((Norm $s)) }
# a registry path under the hives as 'SOFTWARE\...'
function Get-HivePath([string]$p) {
    $i = $p.IndexOf('AkariIso_')
    if ($i -lt 0) { return $null }
    $p.Substring($i + 9).TrimEnd('\')
}
function Test-Denied([string]$p) {
    if ($script:InTrusted) { return $false }
    $h = Get-HivePath $p
    if (-not $h) { return $false }
    foreach ($d in $script:Denied) { if ($h -eq $d -or $h -like "$d\*") { return $true } }
    $false
}
function Clear-Mount([string]$Mount) {
    if (Test-Path -LiteralPath $Mount) { Get-ChildItem -LiteralPath $Mount -Force | ForEach-Object { Microsoft.PowerShell.Management\Remove-Item -LiteralPath $_.FullName -Recurse -Force } }
}

# ---- recorders

function Write-Log([string]$m) { if ($m -and $m.Trim()) { $script:Log.Add((Norm $m.TrimEnd())) } }
function Write-ErrLog([string]$m) { $script:ErrLog.Add((Norm $m)) }
function Set-AkariProgress([int]$Done, [int]$Total, [string]$Step = '') { $script:Progress.Add("$Done/$Total $Step") }
function Add-AkariIsoOperation([hashtable]$Operation) { $script:Ops.Add((Norm "$($Operation.Stage)|$($Operation.Name)|$($Operation.State)|$($Operation.Note)")) }
function Start-Sleep { param([int]$Milliseconds, [int]$Seconds) }

function Mount-AkariDiskImage([string]$Path) { Rec "DiskMount $Path"; Join-Path $script:TestRoot 'drive\' }
function Dismount-AkariDiskImage([string]$Path) { Rec "DiskDismount $Path" }
function Get-AkariDriveInfo([string]$Path) { @{ Free = [long]$script:CaseData.Drive.Free; Format = [string]$script:CaseData.Drive.Format } }
function Get-AkariWimImages([string]$Path) {
    Rec "WimImages $Path"
    $p = $script:CaseData.Wims.PSObject.Properties | Where-Object { $_.Name -eq $Path }
    if ($p) { foreach ($i in @($p.Value)) { @{ Index = [int]$i.Index; Name = [string]$i.Name; Version = [string]$i.Version } } }
}
function Export-AkariWim([string]$Source, [int]$Index, [string]$Dest, [string]$Compression) {
    Rec "Export $Source $Index $Dest $Compression"
    New-Item -Path $Dest -ItemType File -Force | Out-Null
}
function Mount-AkariWim([string]$Path, [int]$Index, [string]$Mount) {
    Rec "Mount $Path $Index $Mount"
    if ($script:CaseData.Fail -eq 'Mount') { throw 'The image could not be mounted.' }
    $files = if ((Split-Path $Path -Leaf) -eq 'boot.wim') { $script:CaseData.BootFiles } else { $script:CaseData.ImageFiles }
    foreach ($f in @($files | Where-Object { $_ })) { New-Item -Path (Join-Path $Mount $f) -ItemType File -Force | Out-Null }
}
function Save-AkariWim([string]$Mount) { Rec "Commit $Mount"; Clear-Mount $Mount }
function Undo-AkariWim([string]$Mount) { Rec "Discard $Mount"; Clear-Mount $Mount }
function Invoke-AkariDism {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $verb = $Arguments[1].TrimStart('/')
    $kinds = @{ 'Disable-Feature' = 'Feature'; 'Remove-Capability' = 'Capability'; 'Remove-Package' = 'Package' }
    if ($verb -eq 'Disable-Feature') { foreach ($x in $Arguments) { if ($x -like '/FeatureName:*') { $script:Disabled[$x.Substring(13)] = $true } } }
    # Turbo's one call is a DISM call on the native side (IImage.Dism), one feature's an IImage.Remove
    $set = $script:CaseData.Choices.Settings
    if ($verb -eq 'Disable-Feature' -and $set -and $set.Turbo) { Rec ('Dism ' + ($Arguments -join ' ')) }
    elseif ($kinds.ContainsKey($verb)) { Rec "Remove $($kinds[$verb]) $($Arguments[0].Substring(7)) $($Arguments[2].Split(':', 2)[1])" }
    else { Rec ('Dism ' + ($Arguments -join ' ')) }
    $code = $script:CaseData.DismCodes.PSObject.Properties | Where-Object { $_.Name -eq $verb }
    if ($code) { [int]$code.Value } else { 0 }
}
function Invoke-AkariRegExe {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $name = $Arguments[1].Substring('HKLM\AkariIso_'.Length)
    if ($Arguments[0] -eq 'load') { Rec "HiveLoad $name $($Arguments[2])" } else { Rec "HiveUnload $name" }
    0
}
$script:RealRegistry = ${function:Invoke-AkariRegistry}
function Invoke-AkariRegistry([hashtable[]]$Entries, [string]$Mode) {
    foreach ($e in $Entries) { if (Test-Denied $e.Path) { throw 'Requested registry access is not allowed.' } }
    & $script:RealRegistry $Entries $Mode
}
function Remove-Item {
    [CmdletBinding()] param([string[]]$LiteralPath, [string[]]$Path, [switch]$Recurse, [switch]$Force)
    foreach ($p in @($LiteralPath)) { if ($p -and (Test-Denied $p)) { throw 'Requested registry access is not allowed.' } }
    Microsoft.PowerShell.Management\Remove-Item @PSBoundParameters
}
function Invoke-AkariRegistryTrusted([hashtable[]]$Entries, [string]$Mode) {
    if ($script:CaseData.Fail -eq 'Trusted') { throw 'TrustedInstaller failed.' }
    foreach ($e in $Entries) { Rec "Trusted $(Get-HivePath $e.Path)" }
    $script:InTrusted = $true
    try { & $script:RealRegistry $Entries $Mode } finally { $script:InTrusted = $false }
}
# Run-Trusted's key delete: the key as the test key's provider path
function Remove-AkariIsoKeyTrusted([string]$Key) {
    $h = Get-HivePath $Key
    Rec "Trusted $h"
    $script:InTrusted = $true
    try { Microsoft.PowerShell.Management\Remove-Item -LiteralPath "$($script:TestReg)$h" -Recurse -Force -ErrorAction SilentlyContinue } finally { $script:InTrusted = $false }
}
function Grant-AkariOwnership([string]$Path) { if (Test-Path -LiteralPath $Path) { Rec "Own $Path" } }
function Copy-AkariToImage([string]$Mount, [string]$Source) { Rec 'AkariOS' }
function Install-AkariAdk { 'C:\ADK\oscdimg.exe' }
function Invoke-AkariExe([string]$Path, [string[]]$Arguments) {
    Rec ('Oscdimg ' + ($Arguments -join ' '))
    if ($script:CaseData.Fail -eq 'Oscdimg') { return 2 }
    # the ISO (the build hashes it)
    [IO.File]::WriteAllText($Arguments[-1], 'iso')
    0
}
function Read-AkariImageApps([string]$Mount) {
    Rec "Read Apps $Mount"
    foreach ($a in @($script:CaseData.ImageApps | Where-Object { $_ })) { @{ Name = [string]$a.Name; Package = [string]$a.Package } }
}
function Get-AkariImageCapabilities([string]$Mount) {
    Rec "Read Capabilities $Mount"
    foreach ($x in @($script:CaseData.ImageCapabilities | Where-Object { $_ })) { if ($x.State -eq 'Installed') { @{ Name = [string]$x.Name; State = [string]$x.State } } }
}
function Get-AkariImageFeatures([string]$Mount) {
    Rec "Read Features $Mount"
    $stuck = @($script:CaseData.StuckFeatures | Where-Object { $_ })
    foreach ($n in @($script:CaseData.ImageFeatures | Where-Object { $_ })) {
        @{ Name = [string]$n; State = $(if ($script:Disabled.ContainsKey([string]$n) -and $stuck -notcontains $n) { 'DisabledWithPayloadRemoved' } else { 'Enabled' }) }
    }
}

# ---- the case

if ($c.Marker) { Set-AkariIsoMarker ([string]$c.Marker.Mount) ([string]$c.Marker.Image) ([int]$c.Marker.Index) }
$outDir = Join-Path $Root 'out'
$iso = Join-Path $Root 'Win11.iso'
$opened = $null
$results = [Collections.Generic.List[object]]::new()
foreach ($a in @($c.Actions)) {
    switch ($a) {
        'Open' {
            try {
                $opened = Open-AkariIsoSource $iso $outDir
                $eds = @(foreach ($e in $opened.Editions) { "$($e.Index)|$($e.Name)|$($e.Version)|$($e.Supported)" })
                $results.Add([ordered]@{ Action = 'Open'; Error = ''; Image = (Norm $opened.Image); Editions = $eds })
            }
            catch { $results.Add([ordered]@{ Action = 'Open'; Error = (Norm $_.Exception.Message); Image = ''; Editions = @() }) }
        }
        'Mount' {
            $err = ''
            try { Mount-AkariIsoEdition $opened.Work $opened.Image ([int]$c.Choices.Index) } catch { $err = Norm $_.Exception.Message }
            $results.Add([ordered]@{ Action = 'Mount'; Error = $err })
        }
        'Build' {
            $ch = $c.Choices
            $choices = @{
                OutDir = $outDir; Iso = $iso; Image = $opened.Image; Index = [int]$ch.Index; Edition = [string]$ch.Edition
                Apps = @($ch.Apps | Where-Object { $_ })
                Features = @($ch.Features | Where-Object { $_ }); Capabilities = @($ch.Capabilities | Where-Object { $_ })
                Packages = @($ch.Packages | Where-Object { $_ })
            }
            if ($ch.AkariOS) { $choices.AkariDir = Join-Path $Root 'akari' }
            if ($ch.Unattend) { $choices.Unattend = [Text.Encoding]::UTF8.GetBytes([string]$ch.Unattend) }
            if ($ch.Settings) { $choices.Settings = $ch.Settings }
            # the wizard
            if ($ch.PSObject.Properties['Groups']) { $choices.Groups = @($ch.Groups | Where-Object { $_ }) }
            if ($ch.AppPatterns) { $choices.AppPatterns = @($ch.AppPatterns) }
            if ($ch.FirstSignIn) { $choices.FirstSignIn = $true }
            if ($ch.ImageBuild) { $choices.ImageBuild = [int]$ch.ImageBuild }
            if ($ch.Bake) {
                $loaded = @((Get-AkariTweaks (Join-Path $Src 'Tweaks')).Tweaks)
                $choices.Bake = @(foreach ($b in @($ch.Bake)) { @{ Tweak = @($loaded | Where-Object { $_.Id -eq $b.Id })[0]; Value = $b.Value } })
            }
            $r = Invoke-AkariIsoBuild $choices
            $results.Add([ordered]@{ Action = 'Build'; Ok = [bool]$r.Ok; Path = (Norm "$($r.Path)"); Message = (Norm "$($r.Message)") })
        }
        'Leftover' { Clear-AkariIsoLeftover; $results.Add([ordered]@{ Action = 'Leftover' }) }
    }
}
$m = Get-AkariIsoMarker
$marker = if ($m) { Norm "$($m.Mount)|$($m.Image)|$($m.Index)" } else { '' }
$o = [ordered]@{ Calls = @($script:Calls); Log = @($script:Log); ErrLog = @($script:ErrLog); Progress = @($script:Progress); Ops = @($script:Ops); Results = @($results); Marker = $marker }
[IO.File]::WriteAllText($Out, (ConvertTo-Json $o -Depth 6 -Compress), [Text.UTF8Encoding]::new($false))
