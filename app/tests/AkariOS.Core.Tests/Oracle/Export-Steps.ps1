# The reference for the native Guided rules (app/AkariOS.Core/Tweaks/Selection.cs): src\UI\Steps.ps1's
# Get-AkariStepGroups on two made-up PCs (as Export-Catalogue.ps1), and on every Tweak src\UI\Selection.ps1's
# Set-AkariPending in fixed scenarios and src\UI\Cards.ps1's Get-AkariRowTip, written as JSON for StepsOracleTests.
# Build 26100 for the Defaults; nothing on this PC is read. Like Export-Tweaks.ps1, it loads the tweak files; no
# block in them runs. Cards.ps1 is not loaded (it needs WPF): Get-AkariRowTip is taken out of its text.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\Registry.ps1')
. (Join-Path $Src 'Core\System.ps1')
. (Join-Path $Src 'UI\Selection.ps1')
$cards = [IO.File]::ReadAllText((Join-Path $Src 'UI\Cards.ps1'))
$m = [regex]::Match($cards, '(?ms)^function Get-AkariRowTip.*?^\}')
. ([scriptblock]::Create($m.Value))
# Steps.ps1 needs WPF too: its Section order and Get-AkariStepGroups, taken out of its text
$steps = [IO.File]::ReadAllText((Join-Path $Src 'UI\Steps.ps1'))
foreach ($p in '(?m)^\$AkariSectionOrder = .*$', '(?m)^\$AkariSectionHeaders = .*$', '(?ms)^function Get-AkariStepGroups.*?^\}') {
    . ([scriptblock]::Create([regex]::Match($steps, $p).Value))
}

$tweaks = (Get-AkariTweaks (Join-Path $Src 'Tweaks')).Tweaks
$pcs = [ordered]@{
    Win11 = @{ Build = 26100; Edition = 'Professional'; Chassis = 'Desktop'; Gpus = @(@{ Vendor = 'NVIDIA' }) }
    Win10 = @{ Build = 19045; Edition = 'Core'; Chassis = 'Laptop'; Gpus = @() }
}
$groups = [ordered]@{}
foreach ($name in $pcs.Keys) {
    $script:Pc = $pcs[$name]
    function Get-AkariOSBuild { $script:Pc.Build }
    function Get-AkariEdition { $script:Pc.Edition }
    function Get-AkariChassis { $script:Pc.Chassis }
    function Get-AkariGpus { $script:Pc.Gpus }
    $groups[$name] = @(Get-AkariStepGroups $tweaks | ForEach-Object {
        [ordered]@{ Section = $_.Section; Header = $_.Header; Categories = @($_.Categories | ForEach-Object { [ordered]@{ Name = $_.Name; Ids = @($_.Ids) } }) }
    })
}
function Get-AkariOSBuild { 26100 }

# one scenario: the pending item Set-AkariPending leaves, or 'none' (a $null would drop out of the list)
function Get-Item($t, [string]$State, $Target, $Current) {
    $sel = New-AkariSelection
    Set-AkariPending $sel $t $State $Target $Current
    if (-not $sel.Contains($t.Id)) { return 'none' }
    $i = $sel[$t.Id]
    [ordered]@{ Mode = $i.Mode; HasValue = $i.ContainsKey('Value'); Value = $(if ($i.ContainsKey('Value')) { "$($i.Value)" } else { $null }); From = [string]$i.From; To = [string]$i.To }
}

$pending = [ordered]@{}
$tips = [ordered]@{}
foreach ($t in $tweaks) {
    $tips[$t.Id] = @('Optimized', 'Default', 'Custom', 'Unknown' | ForEach-Object { Get-AkariRowTip $t $_ })
    $items = if ($t.Kind -eq 'Choice') {
        $def = Resolve-AkariDefault $t.Default
        $first = @($t.Choices)[0].Value
        foreach ($c in $t.Choices) {
            Get-Item $t 'Unknown' $c.Value $null
            Get-Item $t 'Custom' $c.Value $first
            Get-Item $t 'Default' $c.Value $def
        }
        Get-Item $t 'Custom' $def $first
        Get-Item $t 'Custom' 'None' $first
    } else {
        foreach ($s in 'Optimized', 'Default', 'Custom', 'Unknown') { foreach ($x in 'Optimized', 'Default', 'None') { Get-Item $t $s $x $null } }
    }
    $pending[$t.Id] = @($items)
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json ([ordered]@{ Groups = $groups; Pending = $pending; Tips = $tips }) -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
