# The reference for the native Apps lists (app/AkariOS.Core/Tweaks/AppLists.cs): src\UI\Apps.ps1's pure functions
# (Get-AkariAppList, Get-AkariFoundList, Get-AkariInstallList, Get-AkariInstallCards, Get-AkariAppSource,
# Get-AkariAppIconFile, Get-AkariInstallMark, Get-AkariDownloadCategory and Get-AkariDownloadsView's order) on src\Tweaks, written as JSON for AppListsOracleTests. The functions are read out of
# Apps.ps1 (the file's WPF parts never load). Two made-up PCs (the system reads are replaced): Win11 Pro desktop with
# an NVIDIA GPU, Win10 Home laptop with none. What is on the PC is given: -Installed (Store package names), -Capabilities,
# -Features, -Appx (every package name, for the restore card), -Logos ('package=file;…'); each ';'-separated.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [string]$Installed = '', [string]$Capabilities = '',
    [string]$Features = '', [string]$Appx = '', [string]$Logos = '')
$ErrorActionPreference = 'Stop'
function Split-List([string]$s) { @($s.Split(';') | Where-Object { $_ }) }
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\System.ps1')
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Src 'UI\Apps.ps1'), [ref]$null, [ref]$null)
foreach ($fn in 'Get-AkariAppList', 'Get-AkariFoundList', 'Get-AkariInstallList', 'Get-AkariInstallCards', 'Get-AkariAppSource', 'Get-AkariAppIconFile', 'Get-AkariInstallMark', 'Get-AkariDownloadCategory') {
    . ([scriptblock]::Create($ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true).Extent.Text))
}
foreach ($v in 'AkariAppTypes', 'AkariRestoreType', 'AkariDownloadCategories', 'AkariDownloadRestore') {
    . ([scriptblock]::Create($ast.Find({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and "$($n.Left)" -eq "`$$v" }, $true).Extent.Text))
}

$loaded = Get-AkariTweaks (Join-Path $Src 'Tweaks')
$tweaks = $loaded.Tweaks; $groups = $loaded.Groups
$logoMap = @{}
foreach ($p in (Split-List $Logos)) { $k, $f = $p.Split('=', 2); $logoMap[$k] = $f }
$assets = Join-Path $Src 'Assets\Apps'
function ConvertTo-Row($i) {
    [ordered]@{ Id = $i.Tweak.Id; Name = $i.Tweak.Name; Package = $i.Tweak.Package; Installed = [bool]$i.Installed; Keep = [bool]$i.Tweak.Keep
        Risk = "$($i.Tweak.Risk)"; Description = $i.Tweak.Description; Source = (Get-AkariAppSource $i.Tweak)
        Icon = "$(Get-AkariAppIconFile $i.Tweak $logoMap $assets)".Replace($assets, '%Assets%')
        Mark = $(if ($m = Get-AkariInstallMark $i.Tweak) { "$($m.Icon)/$($m.Brush)/$($m.Tip)" } else { '' }) }
}
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
    $result[$name] = [ordered]@{
        Store        = @(Get-AkariAppList $tweaks $groups (Split-List $Installed) | ForEach-Object { ConvertTo-Row $_ })
        Capabilities = @(Get-AkariFoundList $groups 'CapabilityRemove' (Split-List $Capabilities) | ForEach-Object { ConvertTo-Row $_ })
        Features     = @(Get-AkariFoundList $groups 'FeatureDisable' (Split-List $Features) | ForEach-Object { ConvertTo-Row $_ })
        Install      = @(Get-AkariInstallList $tweaks | ForEach-Object { ConvertTo-Row $_ })
        Cards        = @(Get-AkariInstallCards $tweaks (Split-List $Appx) | ForEach-Object { [ordered]@{ Title = $_.Title; Ids = @($_.Items | ForEach-Object { $_.Tweak.Id }) } })
        # Get-AkariDownloadsView: by category in the SelectorBar's order (the Store's restores last), then by name
        Downloads    = @(Get-AkariInstallCards $tweaks (Split-List $Appx) | ForEach-Object { $_.Items } |
            Sort-Object { [array]::IndexOf(@(@($AkariDownloadCategories.Keys) + $AkariDownloadRestore), (Get-AkariDownloadCategory $_.Tweak)) }, { $_.Tweak.Name } |
            ForEach-Object { "$($_.Tweak.Id)=$(Get-AkariDownloadCategory $_.Tweak)=$($_.Tweak.Name)" })
    }
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
