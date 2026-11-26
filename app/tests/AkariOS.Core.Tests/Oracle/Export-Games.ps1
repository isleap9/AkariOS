# The reference for the native per-game settings' pure parts (app/AkariOS.Core/Machine/Games.cs): src\Core\Games.ps1's
# Read-AkariVdf, Select-AkariGameExe and Set- / Test-AkariLayerFlag on the cases GamesTests writes, written back as JSON.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
foreach ($f in 'Log', 'Registry', 'Games') { . (Join-Path $Src "Core\$f.ps1") }

# nested dictionaries as "key=value" lines, children indented by their path, in the text's order
function Format-Vdf($D, [string]$Prefix) {
    foreach ($k in @($D.Keys)) {
        $v = $D[$k]
        if ($v -is [Collections.IDictionary]) { "$Prefix$k/"; Format-Vdf $v "$Prefix$k/" } else { "$Prefix$k=$v" }
    }
}

$c = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json
$result = [ordered]@{
    Vdf    = @(foreach ($t in $c.Vdf) { (@(Format-Vdf (Read-AkariVdf "$t") '')) -join "`n" })
    Exe    = @(foreach ($set in $c.Exe) { Select-AkariGameExe @(foreach ($f in @($set)) { @{ Path = "$($f.Path)"; Size = [long]$f.Size } }) })
    Layers = @(foreach ($l in $c.Layers) { "$(Set-AkariLayerFlag "$($l.Data)" "$($l.Flag)" ([bool]$l.On))|$(Test-AkariLayerFlag "$($l.Data)" "$($l.Flag)")" })
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 4 -Compress), [Text.UTF8Encoding]::new($false))
