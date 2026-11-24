# The reference for the native IsoDownload (app/AkariOS.Core/Iso/IsoDownload.cs): src\Core\IsoDownload.ps1's real
# Invoke-AkariUupApi, Get-AkariUupBuild, Get-AkariUupLanguages, Get-AkariUupEditions, Save-AkariUupIso,
# Get-AkariMassgraveCatalogue, Find-AkariDownloadedIso, and Microsoft's download (Get-AkariMicrosoftHashes,
# Find-AkariNewIso, Test-AkariMicrosoftIso), with recorders in place of the network and the converter
# (Invoke-AkariUupRequest, Save-AkariUupPackage, Invoke-AkariUupScript, Invoke-AkariWebText), Start-Sleep, the log and
# Get-AkariDriveInfo, answering the case (-Case, a JSON file IsoDownloadOracleTests writes). Files only under -Root
# (output <root>\out, the Downloads folder <root>\downloads). Nothing reaches the network.
# Case: Actions (@{ Do = Build | Languages | Editions | Save | Catalogue | Find | Hashes | FindNew | Check; ... }; FindNew's
# Since = minutes before the downloads' clock, 2026-11-13 12:00 UTC), Answers (the API's answers in
# call order: @{ Json } or @{ Throw }), Package (@{ Throw } or @{ Files = @{ name = text } }: the zip made), Script
# (@{ Code; Iso; Lines }), Pages (url -> text, $null = throws), Drive @{ Free; Format }.
# Writes @{ Calls; Log; ErrLog; Results; Files } as JSON to -Out; paths start <root>.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Case,
    [Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
$c = [IO.File]::ReadAllText($Case).Replace('<root>', $Root.Replace('\', '\\')) | ConvertFrom-Json
# script variables: the functions under test have locals of the same names ($c, $r, $Root...)
$script:CaseData = $c
$script:TestRoot = $Root
foreach ($f in 'Log', 'Registry', 'System', 'Iso', 'IsoDownload') { . (Join-Path $Src "Core\$f.ps1") }
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:Calls = [Collections.Generic.List[string]]::new()
$script:Log = [Collections.Generic.List[string]]::new()
$script:ErrLog = [Collections.Generic.List[string]]::new()
$script:Answer = 0

function Norm([string]$s) { $s.Replace($script:TestRoot, '<root>') }
function Rec([string]$s) { $script:Calls.Add((Norm $s)) }
# a hashtable as 'k=v&k=v', keys sorted (all lower-case: the same order as the native side's ordinal sort)
function Show-Query([hashtable]$h) { (@($h.Keys) | Sort-Object | ForEach-Object { "$_=$($h[$_])" }) -join '&' }

# ---- recorders

function Write-Log([string]$m) { if ($m -and $m.Trim()) { $script:Log.Add((Norm $m.TrimEnd())) } }
function Write-ErrLog([string]$m) { $script:ErrLog.Add((Norm $m)) }
function Start-Sleep { param([int]$Seconds, [int]$Milliseconds) Rec "Sleep $Seconds" }
function Get-AkariDriveInfo([string]$Path) { @{ Free = [long]$script:CaseData.Drive.Free; Format = [string]$script:CaseData.Drive.Format } }

function Invoke-AkariUupRequest([string]$Name, [hashtable]$Query) {
    Rec "Api $Name $(Show-Query $Query)"
    $a = @($script:CaseData.Answers)[$script:Answer]
    $script:Answer++
    if ($null -eq $a) { throw 'no answer left' }
    if ($a.Throw) { throw [string]$a.Throw }
    $a.Json
}
function Save-AkariUupPackage([string]$Url, [hashtable]$Body, [string]$OutFile) {
    Rec "Package $Url $(Show-Query $Body)"
    $p = $script:CaseData.Package
    if ($p.Throw) { throw [string]$p.Throw }
    $tmp = Join-Path $script:TestRoot "zip-$([guid]::NewGuid().ToString('N'))"
    New-Item -Path $tmp -ItemType Directory | Out-Null
    foreach ($f in @($p.Files.PSObject.Properties)) { [IO.File]::WriteAllText((Join-Path $tmp $f.Name), [string]$f.Value) }
    [IO.Compression.ZipFile]::CreateFromDirectory($tmp, $OutFile)
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $tmp -Recurse -Force
}
function Invoke-AkariUupScript([string]$Dir) {
    Rec "Script $Dir"
    $ini = Join-Path $Dir 'ConvertConfig.ini'
    Rec ('Ini ' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($ini)))
    $s = $script:CaseData.Script
    foreach ($l in @($s.Lines | Where-Object { $_ })) { Write-Log $l }
    if ($s.Iso) { [IO.File]::WriteAllText((Join-Path $Dir ([string]$s.Iso)), 'iso') }
    [int]$s.Code
}
function Invoke-AkariWebText([string]$Url) {
    Rec "Page $Url"
    $p = $script:CaseData.Pages.PSObject.Properties | Where-Object { $_.Name -eq $Url }
    if (-not $p -or $null -eq $p.Value) { throw '404 Not Found' }
    [string]$p.Value
}

# ---- the case

$outDir = Join-Path $Root 'out'
$results = [Collections.Generic.List[string]]::new()
foreach ($a in @($c.Actions)) {
    switch ($a.Do) {
        'Build' {
            $r = Get-AkariUupBuild ([string]$a.Version)
            $b = if ($r.Ok) { "$($r.Build.Id)|$($r.Build.Title)|$($r.Build.Build)" } else { '' }
            $results.Add("Build;Ok=$($r.Ok);Value=$b;Message=$(Norm $r.Message)")
        }
        'Languages' {
            $r = Get-AkariUupLanguages ([string]$a.Id)
            $v = if ($r.Ok) { (@($r.Items) | ForEach-Object { "$($_.Code):$($_.Name)" }) -join ',' } else { '' }
            $results.Add("Languages;Ok=$($r.Ok);Value=$v;Message=$(Norm $r.Message)")
        }
        'Editions' {
            $r = Get-AkariUupEditions ([string]$a.Id) ([string]$a.Lang)
            $v = if ($r.Ok) { (@($r.Items) | ForEach-Object { "$($_.Label)|$($_.Code)|$($_.Virtual)" }) -join ',' } else { '' }
            $results.Add("Editions;Ok=$($r.Ok);Value=$v;Message=$(Norm $r.Message)")
        }
        'Save' {
            $build = @{ Id = [string]$a.Build.Id; Title = [string]$a.Build.Title; Build = [string]$a.Build.Build }
            $target = @{ Label = [string]$a.Target.Label; Code = [string]$a.Target.Code; Virtual = [string]$a.Target.Virtual }
            $r = Save-AkariUupIso ([string]$a.Version) $build ([string]$a.Lang) $target $outDir
            $results.Add("Save;Ok=$($r.Ok);Value=$(Norm "$($r.Path)");Message=$(Norm $r.Message)")
        }
        'Catalogue' {
            $r = Get-AkariMassgraveCatalogue
            $v = (@($r.Items) | ForEach-Object { "$($_.Product)|$($_.Language)|$($_.File)|$($_.Url)" }) -join ','
            $results.Add("Catalogue;Ok=$($r.Ok);Value=$v;Message=$(Norm $r.Message)")
        }
        'Find' {
            $r = Find-AkariDownloadedIso ([string]$a.File) (Join-Path $Root 'downloads')
            $results.Add("Find;Value=$(Norm "$r")")
        }
        'Hashes' {
            $r = Get-AkariMicrosoftHashes
            $v = (@($r.Items) | ForEach-Object { "$($_.Language)|$($_.Sha256)" }) -join ','
            $results.Add("Hashes;Ok=$($r.Ok);Value=$v;Message=$(Norm $r.Message)")
        }
        'FindNew' {
            $since = [datetime]::new(2026, 11, 13, 12, 0, 0, [DateTimeKind]::Utc).AddMinutes(-[int]$a.Since)
            $r = Find-AkariNewIso ([string]$a.Pattern) $since (Join-Path $Root 'downloads')
            $results.Add("FindNew;Value=$(Norm "$r")")
        }
        'Check' {
            $h = Get-AkariMicrosoftHashes
            $r = Test-AkariMicrosoftIso (Join-Path (Join-Path $Root 'downloads') ([string]$a.File)) $h.Items
            $results.Add("Check;Value=$($r.Language)")
        }
    }
}
$files = @(if (Test-Path -LiteralPath $outDir) { Get-ChildItem -LiteralPath $outDir -Recurse -Force | ForEach-Object { Norm $_.FullName } | Sort-Object })
$o = [ordered]@{ Calls = @($script:Calls); Log = @($script:Log); ErrLog = @($script:ErrLog); Results = @($results); Files = $files }
[IO.File]::WriteAllText($Out, (ConvertTo-Json $o -Depth 6 -Compress), [Text.UTF8Encoding]::new($false))
