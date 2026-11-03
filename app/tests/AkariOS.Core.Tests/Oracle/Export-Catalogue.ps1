# The reference for the native Catalogue (app/AkariOS.Core/Tweaks/Catalogue.cs): src\UI\Catalogue.ps1's pages, page
# lists and search on src\Tweaks, written as JSON for CatalogueOracleTests. Two made-up PCs (the system reads are
# replaced, so nothing on this PC is read): Win11 Pro desktop with an NVIDIA GPU, and Win10 Home laptop with none.
# Like Export-Tweaks.ps1, it loads the tweak files; no block in them runs.
# $Queries: the searches, comma separated (-File passes one string)
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [string]$Queries = '')
$ErrorActionPreference = 'Stop'
$searches = @($Queries.Split(',') | Where-Object { $_ })
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\System.ps1')
. (Join-Path $Src 'UI\Catalogue.ps1')

$tweaks = (Get-AkariTweaks (Join-Path $Src 'Tweaks')).Tweaks
$pcs = [ordered]@{
    Win11 = @{ Build = 26100; Edition = 'Professional'; Chassis = 'Desktop'; Gpus = @(@{ Vendor = 'NVIDIA' }) }
    Win10 = @{ Build = 19045; Edition = 'Core'; Chassis = 'Laptop'; Gpus = @() }
}
$result = [ordered]@{}
foreach ($name in $pcs.Keys) {
    $script:Pc = $pcs[$name]
    function Get-AkariOSBuild { $script:Pc.Build }
    function Get-AkariEdition { $script:Pc.Edition }
    function Get-AkariChassis { $script:Pc.Chassis }
    function Get-AkariGpus { $script:Pc.Gpus }
    $pages = @(Get-AkariCataloguePages $tweaks)
    $lists = [ordered]@{}
    foreach ($s in $pages) { foreach ($p in $s.Pages) { $lists[$p.Key] = @(Get-AkariCatalogueList $tweaks $p.Key '' | ForEach-Object { $_.Id }) } }
    $search = [ordered]@{}
    foreach ($q in $searches) { $search[$q] = @(Get-AkariCatalogueList $tweaks '' $q | ForEach-Object { $_.Id }) }
    $result[$name] = [ordered]@{
        Tweaks = @(Get-AkariCatalogueTweaks $tweaks | ForEach-Object { $_.Id })
        Pages  = @($pages | ForEach-Object { [ordered]@{ Section = $_.Section; Header = $_.Header; Pages = @($_.Pages | ForEach-Object { [ordered]@{ Key = $_.Key; Category = $_.Category } }) } })
        Lists  = $lists
        Search = $search
    }
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
