# The reference for the native updater (app/AkariOS.Core/Update/Updates.cs): src\Core\Update.ps1's
# ConvertTo-AkariNotesText, Get-AkariLatestRelease and Get-AkariUpdateStatus on the cases UpdateOracleTests writes,
# written back as JSON. GitHub is never reached: Invoke-AkariGitHubApi answers each case's canned Status / Body /
# ResetAt. Get-AkariUpdateStatus reads a temp install folder (no .git) and a temp $AkariRunPath, removed after.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Update.ps1')

$c = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json
$tmp = Join-Path ([IO.Path]::GetTempPath()) "akari-oracle-update-$([guid]::NewGuid().ToString('N'))"
$install = Join-Path $tmp 'AkariOS'
New-Item $install -ItemType Directory -Force | Out-Null
$runFile = Join-Path $tmp 'run.json'

$result = [ordered]@{ Notes = @(); Releases = @(); Status = @() }
try {
    # a missing list is no list (@($null) would loop once)
    if ($null -ne $c.Notes) { $result.Notes = @(foreach ($md in @($c.Notes)) { ConvertTo-AkariNotesText $md }) }

    if ($null -ne $c.Releases) { $result.Releases = @(foreach ($r in @($c.Releases)) {
        $script:Answer = @{ Status = [int]$r.Status; Body = $r.Body; ResetAt = $(if ($r.ResetAt) { [datetime]$r.ResetAt } else { $null }) }
        function Invoke-AkariGitHubApi([string]$Path) { $script:Answer }
        $x = Get-AkariLatestRelease
        [ordered]@{ Ok = [bool]$x.Ok; Version = $(if ($x.Version) { "$($x.Version)" } else { '' }); Message = "$($x.Message)"
            Notes = "$($x.Notes)"; PageUrl = "$($x.PageUrl)" }
    }) }

    if ($null -ne $c.Status) { $result.Status = @(foreach ($s in @($c.Status)) {
        if ($s.Run) { Set-Content $runFile '{}' } elseif (Test-Path $runFile) { Remove-Item $runFile }
        $AkariRunPath = $runFile
        $release = if ($s.Ok) { @{ Ok = $true; Version = [version]$s.Version; Message = $null } } else { @{ Ok = $false; Message = $s.Message } }
        $x = Get-AkariUpdateStatus $s.Current $release $install ([bool]$s.Busy)
        [ordered]@{ Kind = $x.Kind; Message = $x.Message }
    }) }
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
