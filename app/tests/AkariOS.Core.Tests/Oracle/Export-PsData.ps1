# The reference for the native PsData reader (app/AkariOS.Core/PsData): every file the native app shares with the
# PowerShell app, read the way the PowerShell app reads it (a tweak file through & <file>, as Core\Loader.ps1 does; a
# .psd1 through Import-PowerShellDataFile), written as JSON for PsDataOracleTests to compare. It only builds the
# hashtables: no block in them runs. Numbers keep their .NET type, byte arrays become hex, script blocks a marker.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture

function ConvertTo-Plain($v) {
    if ($null -eq $v) { return $null }
    if ($v -is [scriptblock]) { return @{ '$block' = 1 } }
    if ($v -is [byte[]]) { return @{ '$bytes' = (($v | ForEach-Object { $_.ToString('x2') }) -join '') } }
    if ($v -is [Collections.IDictionary]) {
        $o = [ordered]@{}
        foreach ($k in @($v.Keys | ForEach-Object { [string]$_ } | Sort-Object)) { $o[$k] = ConvertTo-Plain $v[$k] }
        return $o
    }
    if ($v -is [string] -or $v -is [bool]) { return $v }
    if ($v -is [Collections.IEnumerable]) {
        $l = [Collections.ArrayList]::new()
        foreach ($x in $v) { [void]$l.Add((ConvertTo-Plain $x)) }
        return , $l
    }
    if ($v -is [double]) { return @{ '$num' = $v.ToString('R', $inv); '$type' = 'Double' } }
    if ($v -is [ValueType]) { return @{ '$num' = $v.ToString($null, $inv); '$type' = $v.GetType().Name } }
    return [string]$v
}

$tweaks = Join-Path $Src 'Tweaks'
$files = @()
# one-file tweaks: src/Tweaks/<Section>/<Category>/*.ps1 (not Legacy's src/Tweaks/*.ps1, not the Files/ helpers)
foreach ($section in Get-ChildItem $tweaks -Directory) {
    foreach ($category in Get-ChildItem $section.FullName -Directory) {
        $files += Get-ChildItem $category.FullName -File -Filter *.ps1
    }
    $files += Get-ChildItem $section.FullName -Recurse -File -Filter *.psd1
}
$files += Get-ChildItem (Join-Path $Src 'Core\Iso\Data') -Recurse -File -Filter *.psd1
$files += Get-ChildItem (Join-Path $Src 'UI') -File -Filter *.psd1

$result = [ordered]@{}
foreach ($f in $files) {
    $rel = 'src/' + $f.FullName.Substring($Src.TrimEnd('\').Length + 1).Replace('\', '/')
    try {
        $value = if ($f.Extension -eq '.psd1') { Import-PowerShellDataFile -LiteralPath $f.FullName } else { & $f.FullName }
        $result[$rel] = ConvertTo-Plain $value
    } catch {
        $result[$rel] = @{ '$error' = "$_" }
    }
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json @{ Files = $result } -Depth 100 -Compress), [Text.UTF8Encoding]::new($false))
