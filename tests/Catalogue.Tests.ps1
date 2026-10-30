$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# The Catalogue's pure part (UI\Catalogue.ps1): what Optimize › Advanced lists, its pages, search, the Safe Mode waiting
# list and the restart bar. No WPF; fixture Tweaks only.

Describe 'Catalogue (Optimize > Advanced)' {
    foreach ($f in 'Registry', 'Loader', 'System') { . "$Core\$f.ps1" }
    . "$Root\UI\Catalogue.ps1"
    Mock Test-AkariRequirement { if ($Tweak.Requires -contains 'NVIDIA') { 'needs NVIDIA' } }
    function T([hashtable]$h, [bool]$Legacy = $false) {
        foreach ($k in 'Name', 'Description', 'Risk') { if (-not $h.ContainsKey($k)) { $h[$k] = $(if ($k -eq 'Risk') { 'Safe' } else { $h.Id }) } }
        ConvertTo-AkariTweak $h 'x' $Legacy
    }
    $all = @(
        T @{ Id = 'game'; Section = 'Optimize'; Category = 'Gaming'; Description = 'faster games' }
        T @{ Id = 'priv'; Section = 'Optimize'; Category = 'Privacy' }
        T @{ Id = 'bar'; Section = 'Customize'; Category = 'Taskbar' }
        T @{ Id = 'check'; Section = 'Tools'; Category = 'Check'; Kind = 'Action' }
        T @{ Id = 'sec'; Section = 'Advanced'; Category = 'Security' }
        T @{ Id = 'odd'; Section = 'Zeta'; Category = 'Misc' }
        T @{ Id = 'gpu'; Section = 'Hardware'; Category = 'Graphics'; Requires = 'NVIDIA' }
        T @{ Id = 'only'; Section = 'Customize'; Category = 'Taskbar'; Guided = $false; Name = 'Only here' }
        T @{ Id = 'appx/x'; Section = 'Apps'; Category = 'Remove'; Group = 'appx'; Kind = 'Action' }
        T @{ Id = 'oc'; Section = 'OneClick'; Category = 'Finish'; Kind = 'Action' }
        T @{ Id = 'old'; Section = 'Windows'; Category = '' } $true
    )

    It 'lists one-file Toggles, Choices and Actions this PC meets, Tools and Advanced-only ones included' {
        (Get-AkariCatalogueTweaks $all | ForEach-Object { $_.Id }) -join ',' | Should Be 'game,priv,bar,check,sec,odd,only'
    }
    It 'orders the sidebar Optimize, Customize, (Graphics & Hardware), Advanced, Tools, then the rest' {
        $p = @(Get-AkariCataloguePages $all)
        ($p | ForEach-Object { $_.Header }) -join ',' | Should Be 'Optimize,Customize,Advanced,Tools,Zeta'
        ($p[0].Pages | ForEach-Object { $_.Key }) -join ',' | Should Be 'Catalogue:Optimize/Gaming,Catalogue:Optimize/Privacy'
    }
    It 'gives a page its Tweaks, and search every match in sidebar order' {
        (Get-AkariCatalogueList $all 'Catalogue:Customize/Taskbar' '' | ForEach-Object { $_.Id }) -join ',' | Should Be 'bar,only'
        (Get-AkariCatalogueList $all '' 'game' | ForEach-Object { $_.Id }) -join ',' | Should Be 'game'
        # name or description, across Sections, in sidebar order (Optimize, Customize, Advanced, Tools)
        (Get-AkariCatalogueList $all '' 'e' | ForEach-Object { $_.Id }) -join ',' | Should Be 'game,only,sec,check'
    }
    It 'shows "Graphics & Hardware" for Hardware' {
        $hw = @($all) + @(T @{ Id = 'mouse'; Section = 'Hardware'; Category = 'Input' })
        (@(Get-AkariCataloguePages $hw) | ForEach-Object { $_.Header }) -join ',' | Should Be 'Optimize,Customize,Graphics & Hardware,Advanced,Tools,Zeta'
    }
    It 'keeps a Safe Mode change waiting, and drops it when switched back to where it is' {
        $p = @{}
        $sec = $all | Where-Object { $_.Id -eq 'sec' }
        Set-AkariSafePending $p $sec 'Default' 'Apply'
        $p['sec'].Mode | Should Be 'Apply'
        Set-AkariSafePending $p $sec 'Default' 'Revert'
        $p.Count | Should Be 0
        Set-AkariSafePending $p $sec 'Optimized' 'Revert'
        $p['sec'].Mode | Should Be 'Revert'
    }
    It 'keeps a Choice value on the Safe Mode waiting list, and drops it once the Choice has it' {
        $p = @{}
        $ch = [pscustomobject]@{ Id = 'svc'; Kind = 'Choice' }
        Set-AkariSafePending $p $ch 'Optimized' 'Apply' 'Light' 'Off'
        $p['svc'].Mode | Should Be 'Apply'
        $p['svc'].Value | Should Be 'Light'
        Set-AkariSafePending $p $ch 'Custom' 'Apply' 'Light' 'Light'
        $p.Count | Should Be 0
    }
    It 'words the restart bar by count' {
        (Get-AkariRestartBarText 1 0) -join '|' | Should Be 'Explorer needs a restart to show 1 change.'
        (Get-AkariRestartBarText 3 2) -join '|' | Should Be 'Explorer needs a restart to show 3 changes.|A restart finishes 2 changes.'
        @(Get-AkariRestartBarText 0 0).Count | Should Be 0
    }
    It 'words a card''s State line' {
        $g = $all | Where-Object { $_.Id -eq 'game' }
        Get-AkariCatalogueStateText $g 'Default' '' $false | Should Be 'Windows default'
        Get-AkariCatalogueStateText $g 'Custom' '' $false | Should Be 'Custom value'
        Get-AkariCatalogueStateText $g 'Optimized' '' $true | Should Be 'Waiting for Safe Mode'
        Get-AkariCatalogueStateText $g 'Optimized' 'Running' $false | Should Match '^Applying'
        Get-AkariCatalogueStateText ($all | Where-Object { $_.Id -eq 'check' }) 'Unknown' '' $false | Should Be ''
    }
    It 'the loader marks a Tweak Guided unless its file says Guided = $false' {
        ($all | Where-Object { $_.Id -eq 'game' }).Guided | Should Be $true
        ($all | Where-Object { $_.Id -eq 'only' }).Guided | Should Be $false
    }
    It 'Guided''s Tweaks step leaves out Tools and Guided = $false Tweaks' {
        foreach ($f in 'Selection', 'Steps') { . "$Root\UI\$f.ps1" }
        $ids = @(Get-AkariStepGroups $all | ForEach-Object { $_.Categories } | ForEach-Object { $_.Ids })
        $ids -contains 'check' | Should Be $false
        $ids -contains 'only' | Should Be $false
        $ids -contains 'bar' | Should Be $true
    }
}
