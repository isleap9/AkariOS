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
    It 'keeps each page''s own order in the search, not only the page order' {
        $two = @((T @{ Id = 'z-first'; Section = 'Optimize'; Category = 'Gaming'; Name = 'Zz match' }), (T @{ Id = 'a-second'; Section = 'Optimize'; Category = 'Gaming'; Name = 'Aa match' }))
        (Get-AkariCatalogueList $two '' 'match' | ForEach-Object { $_.Id }) -join ',' | Should Be 'z-first,a-second'
        @(Get-AkariCatalogueList $two 'Catalogue:Optimize/Nothing' '').Count | Should Be 0
    }
    It 'works the GUI''s Catalogue out once, again only when the loaded list is another one or grows' {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($t in $all) { $list.Add($t) }
        $a = Get-AkariCatalogueOf $list
        [object]::ReferenceEquals($a, (Get-AkariCatalogueOf $list)) | Should Be $true
        (Find-AkariCatalogueList $a 'Catalogue:Customize/Taskbar' '' | ForEach-Object { $_.Id }) -join ',' | Should Be 'bar,only'
        (Find-AkariCatalogueList $a '' 'e' | ForEach-Object { $_.Id }) -join ',' | Should Be 'game,only,sec,check'
        $list.Add((T @{ Id = 'new'; Section = 'Optimize'; Category = 'Gaming' }))
        $b = Get-AkariCatalogueOf $list
        [object]::ReferenceEquals($a, $b) | Should Be $false
        (Find-AkariCatalogueList $b 'Catalogue:Optimize/Gaming' '' | ForEach-Object { $_.Id }) -join ',' | Should Be 'game,new'
        $other = [System.Collections.Generic.List[object]]::new($list)
        [object]::ReferenceEquals($b, (Get-AkariCatalogueOf $other)) | Should Be $false
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
    It 'a Section''s page lists its Categories in the order and groups of Categories.psd1, the unknown ones under More' {
        $more = @(
            T @{ Id = 'bar2'; Section = 'Customize'; Category = 'Start' }
            T @{ Id = 'z1'; Section = 'Customize'; Category = 'Zany'; Name = 'One' }
            T @{ Id = 'z2'; Section = 'Customize'; Category = 'Zany'; Name = 'Two' }
            T @{ Id = 'z3'; Section = 'Customize'; Category = 'Zany'; Name = 'Three' }
            T @{ Id = 'z4'; Section = 'Customize'; Category = 'Zany'; Name = 'Four' }
        )
        $info = @(
            @{ Section = 'Customize'; Category = 'Start'; Group = 'Desktop'; Line = 'Pins' }
            @{ Section = 'Optimize'; Category = 'Gaming'; Group = 'Speed'; Line = 'Games' }
            @{ Section = 'Customize'; Category = 'Taskbar'; Group = 'Desktop'; Line = 'The bar' }
        )
        $rows = @(Get-AkariCategoryRows (New-AkariCatalogue ($all + $more)) 'Customize' $info)
        ($rows | ForEach-Object { "$($_.Category):$($_.Group):$($_.Count):$($_.Key)" }) -join ',' |
            Should Be 'Start:Desktop:1:Catalogue:Customize/Start,Taskbar:Desktop:2:Catalogue:Customize/Taskbar,Zany:More:4:Catalogue:Customize/Zany'
        $rows[2].Line | Should Be ('One, Two, Three, ' + [char]0x2026)
        $rows[0].Line | Should Be 'Pins'
        @(Get-AkariCategoryRows (New-AkariCatalogue $all) 'Nowhere' $info).Count | Should Be 0
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
        $AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
        foreach ($f in 'Selection', 'Steps') { . "$Root\UI\$f.ps1" }
        $ids = @(Get-AkariStepGroups $all | ForEach-Object { $_.Categories } | ForEach-Object { $_.Ids })
        $ids -contains 'check' | Should Be $false
        $ids -contains 'only' | Should Be $false
        $ids -contains 'bar' | Should Be $true
    }
}

# UI\Categories.psd1 (shared with the native app's Shell/CategoryInfo): every Category of every Catalogue Section has its
# row, so none falls under "More"
Describe 'Categories.psd1' {
    foreach ($f in 'Registry', 'Loader', 'System') { . "$Core\$f.ps1" }
    . "$Root\UI\Catalogue.ps1"
    Mock Test-AkariRequirement { $null }
    $info = @((Import-PowerShellDataFile "$Root\UI\Categories.psd1").Categories)
    $cat = New-AkariCatalogue (Get-AkariTweaks "$Root\Tweaks").Tweaks
    It 'has a row for every Category, with a line' {
        $missing = @(foreach ($s in $cat.Pages) { foreach ($r in @(Get-AkariCategoryRows $cat $s.Section $info)) { if ($r.Group -eq $AkariCategoryMore) { "$($s.Section)/$($r.Category)" } } })
        $missing -join ',' | Should Be ''
        @($info | Where-Object { -not $_.Line -or -not $_.Section -or -not $_.Category -or $null -eq $_.Group }).Count | Should Be 0
    }
    It 'names only Sections and Categories that exist' {
        $have = @(foreach ($s in $cat.Pages) { foreach ($p in $s.Pages) { "$($s.Section)/$($p.Category)" } })
        (@($info | ForEach-Object { "$($_.Section)/$($_.Category)" } | Where-Object { $_ -notin $have }) -join ',') | Should Be ''
    }
}
