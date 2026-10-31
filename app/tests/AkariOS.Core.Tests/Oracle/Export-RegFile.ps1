# The reference for the native RegReader (app/AkariOS.Core/Data/RegReader.cs): the PowerShell app's two .reg readers
# on the shared .reg files, written as JSON for RegReaderTests. Read-AkariRegFile (tests\RegFile.ps1) on
# OneClick\reg.reg; ConvertFrom-AkariRegExport (Core\AppSetup.ps1, with ConvertFrom-AkariHex from Core\Registry.ps1:
# only those two functions are defined, nothing else in the files runs) on the Store settings with {0} = 00.
param([Parameter(Mandatory)][string]$Repo, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'

. (Join-Path $Repo 'tests\RegFile.ps1')
foreach ($pair in @(@('src\Core\AppSetup.ps1', 'ConvertFrom-AkariRegExport'), @('src\Core\Registry.ps1', 'ConvertFrom-AkariHex'))) {
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo $pair[0]), [ref]$null, [ref]$null)
    $fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $pair[1] }, $true)
    . ([scriptblock]::Create($fn.Extent.Text))
}

function ConvertTo-Plain($v) {
    if ($null -eq $v) { return $null }
    if ($v -is [byte[]]) { return @{ '$bytes' = (($v | ForEach-Object { $_.ToString('x2') }) -join '') } }
    if ($v -is [string]) { return $v }
    if ($v -is [Collections.IEnumerable]) { $l = [Collections.ArrayList]::new(); foreach ($x in $v) { [void]$l.Add((ConvertTo-Plain $x)) }; return , $l }
    if ($v -is [ValueType]) { return @{ '$num' = [string]$v; '$type' = $v.GetType().Name } }
    [string]$v
}
function ConvertTo-PlainMap($map) {
    $o = [ordered]@{}
    foreach ($k in @($map.Keys | Sort-Object)) { $o[$k] = ConvertTo-Plain $map[$k] }
    $o
}

$reg = Read-AkariRegFile (Join-Path $Repo 'src\OneClick\reg.reg')
$storeText = (Get-Content -LiteralPath (Join-Path $Repo 'src\Tweaks\Customize\Apps\Files\store-settings.reg') -Raw).Replace('{0}', '00')
$store = ConvertFrom-AkariRegExport $storeText 'HKEY_LOCAL_MACHINE\AkariAppHive'
$json = ConvertTo-Json @{ RegReg = (ConvertTo-PlainMap $reg); Store = (ConvertTo-PlainMap $store) } -Depth 20 -Compress
[IO.File]::WriteAllText($Out, $json, [Text.UTF8Encoding]::new($false))
