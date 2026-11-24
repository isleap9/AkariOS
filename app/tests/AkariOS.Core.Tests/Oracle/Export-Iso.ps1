# The reference for the native ISO Builder's pure parts (app/AkariOS.Core/Iso/): src\Core\Iso.ps1, Iso\Image.ps1,
# IsoDownload.ps1 and UI\IsoBuilder.ps1's pure helpers on the cases IsoOracleTests writes, written back as JSON.
# Nothing touches the PC: Get-AkariDriveInfo and Get-AkariWimImages answer each case, the oscdimg cases read the C#
# test's temp folders, nothing reaches the network.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
$AkariIsoMarker = Join-Path ([IO.Path]::GetTempPath()) "akari-oracle-iso-$([guid]::NewGuid().ToString('N')).json"
foreach ($f in 'Log', 'Registry', 'Trusted', 'AppSetup', 'System', 'Runner', 'Iso', 'IsoDownload') { . (Join-Path $Src "Core\$f.ps1") }
$window = $null
. (Join-Path $Src 'UI\IsoBuilder.ps1')

$c = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json

# a JSON object as a hashtable (ConvertFrom-Json keeps a one-item array as an array)
function ConvertTo-Hash($o) {
    $h = @{}
    if ($null -ne $o) { foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = $p.Value } }
    $h
}
# a function's list unrolled: several of them return it with a leading comma (one array down the pipeline)
function Items($v) { foreach ($i in $v) { $i } }
# a value as text: bytes as hex, $null as 'null', else type-free text
function Show($v) {
    if ($null -eq $v) { return 'null' }
    if ($v -is [byte[]]) { return 'hex:' + (($v | ForEach-Object { $_.ToString('x2') }) -join '') }
    "$v"
}
function Show-Row($r) {
    [ordered]@{ Path = $r.Path; Name = $(if ($r.ContainsKey('Name')) { "$($r.Name)" } else { $null }); Type = "$($r.Type)"; Value = (Show $r.Value)
        Trusted = [bool]$r.Trusted; Hive = "$($r.Hive)" }
}

$groups = Get-AkariIsoGroups
$result = [ordered]@{}

# every removal group's rows, merged and mapped as Write-AkariIsoRegistry does, and its boot.wim rows (indexed: a
# hashtable's .Remove would be its method)
function Get-Rows($Rows) { @(ConvertTo-AkariIsoRows (Merge-AkariIsoRows @(@($Rows) | Where-Object { $_ })) | ForEach-Object { Show-Row $_ }) }
$result.GroupRows = @(foreach ($g in $groups) { [ordered]@{ Id = $g.Id; Rows = @(Get-Rows $g['Registry']); Boot = @(Get-Rows $g['Boot']) } })
# every group's rows merged together (several "hide:" lists of Settings' pages become one row)
$result.MergedAll = @(Get-Rows @($groups | ForEach-Object { $_['Registry'] } | Where-Object { $_ }))

$result.Plans = @(foreach ($p in @($c.Plans)) {
    $ch = ConvertTo-Hash $p
    , @(Items (New-AkariIsoPlan $ch (Get-AkariIsoGroupsPicked $ch.Groups $groups)) | ForEach-Object { "$($_.Id)|$($_.Text)" })
})
$result.Resolve = @(foreach ($r in @($c.Resolve)) { , @(Items (Resolve-AkariIsoNames @($r.Picked) @($r.Patterns) @($r.Available))) })
$result.Families = @(foreach ($p in @($c.Families)) { Get-AkariAppFamily $p })
$result.OutNames = @(foreach ($p in @($c.OutNames)) { Get-AkariIsoOutName $p })
$result.Oscdimg = @(foreach ($m in @($c.Oscdimg)) {
    try { (Get-AkariOscdimgArgs $m 'D:\out.iso') -join '|' } catch { "error:$($_.Exception.Message)" }
})
$result.Space = @(foreach ($s in @($c.Space)) {
    $script:Drive = @{ Free = [long]$s.Free; Format = $s.Format }
    function Get-AkariDriveInfo([string]$Path) { $script:Drive }
    "$(Test-AkariIsoSpace 'D:\out')"
})
$result.Editions = @(foreach ($set in @($c.Editions)) {
    $script:Images = @(foreach ($i in @($set)) { @{ Index = [int]$i.Index; Name = $i.Name; Version = $i.Version; Architecture = 'x64' } })
    function Get-AkariWimImages([string]$Path) { $script:Images }
    , @(Items (Get-AkariIsoEditions 'x.wim') | ForEach-Object { "$($_.Index)|$($_.Name)|$($_.Version)|$($_.Supported)" })
})
$defaults = (Import-PowerShellDataFile (Join-Path $Src 'UI\Unattend.psd1')).Defaults
$result.Answers = @(foreach ($a in @($c.Answers)) {
    $f = Get-AkariIsoAnswerFields $defaults ([string]$a[0]) ([string]$a[1]) ([bool]$a[2])
    $o = [ordered]@{}
    foreach ($k in @($f.Keys | Sort-Object)) { $o[[string]$k] = "$($f[$k])" }
    $o
})
$result.Recommended = @(foreach ($r in @($c.Recommended)) {
    $tweaks = @(foreach ($t in @($r.Tweaks)) { ConvertTo-Hash $t })
    $apps = @(foreach ($a in @($r.Apps)) { ConvertTo-Hash $a })
    , @(Get-AkariIsoRecommendedApps $apps $tweaks)
})

# Massgrave and UUP Dump's pure parts
$items = @(Read-AkariMassgrave ([IO.File]::ReadAllText($c.Massgrave)))
$result.Massgrave = @($items | ForEach-Object { "$($_.Product)|$($_.Language)|$($_.File)|$($_.Url)" })
$result.MassgraveProducts = @(Get-AkariMassgraveProducts $items)
$result.MassgraveFiles = @(foreach ($p in @(Get-AkariMassgraveProducts $items)) { , @(Get-AkariMassgraveFiles $items $p | ForEach-Object { $_.Language }) })
$result.UupBuilds = @(foreach ($b in @($c.UupBuilds)) {
    $list = ConvertTo-AkariUupBuilds $b.Builds
    $pick = Select-AkariUupBuild $list $b.Number
    [ordered]@{ All = @($list | ForEach-Object { "$($_.Id)|$($_.Title)|$($_.Build)|$($_.Arch)" }); Pick = $(if ($pick) { $pick.Id } else { '' }) }
})
$result.UupTargets = @(foreach ($f in @($c.UupTargets)) { , @(Items (Get-AkariUupTargets $f) | ForEach-Object { "$($_.Label)|$($_.Code)|$($_.Virtual)" }) })
$result.UupBodies = @(foreach ($v in @($c.UupVirtual)) {
    $b = Get-AkariUupPackageBody $v
    @($b.Keys | Sort-Object | ForEach-Object { "$_=$($b[$_])" }) -join '&'
})
$result.UupConfigs = @(foreach ($v in @($c.UupVirtual)) { , @(Set-AkariUupConfig @($c.UupConfig) $v) })
$result.UupNames = @(foreach ($n in @($c.UupNames)) { Get-AkariUupIsoName $n[0] $n[1] $n[2] })

[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
