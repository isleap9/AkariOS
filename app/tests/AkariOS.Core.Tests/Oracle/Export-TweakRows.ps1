# The reference for Tweak classes that build data with code (app/AkariOS.Tweaks): the Registry rows PowerShell
# evaluates for each Tweak in -Ids (its file run, as the Loader does: a foreach, a -join), and the hosts lines of
# Optimize\Network\Files\RazerAsusHosts.ps1, written as JSON for the Tweaks tests. No block in the files runs.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [string]$Ids = '')
$ErrorActionPreference = 'Stop'
$root = Join-Path $Src 'Tweaks'
$text = { param($v) if ($null -eq $v) { $null } else { "$v" } }
$rows = [ordered]@{}
foreach ($id in @($Ids.Split(',') | Where-Object { $_ })) {
    $file = Get-ChildItem $root -Recurse -Filter *.ps1 | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match "Id\s*=\s*'$([regex]::Escape($id))'" } | Select-Object -First 1
    $h = & $file.FullName
    $rows[$id] = @(foreach ($r in @($h.Registry)) {
        [ordered]@{ Path = $r.Path; Name = $(if ($r.ContainsKey('Name')) { [string]$r.Name } else { $null }); Type = & $text $r.Type; Value = & $text $r.Value; Default = & $text $r.Default }
    })
}
. (Join-Path $root 'Optimize\Network\Files\RazerAsusHosts.ps1')
$result = [ordered]@{ Rows = $rows; RazerAsusHosts = @(Get-AkariRazerAsusHosts) }
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
