# Catalogue (Optimize › Advanced, ADR 0005): every one-file Tweak on Section › Category pages, each change acting right
# away. This file is the pure part (no WPF): what is listed, the pages, search, the Safe Mode waiting list and the
# restart bar text. The page itself is UI\CataloguePage.ps1. Dot-sourced by Akari.ps1 before UI\Cards.ps1.

# page keys: 'Catalogue:<Section>/<Category>', and the search results page
$AkariCataloguePrefix = 'Catalogue:'
$AkariCatalogueSearch = 'Catalogue:Search'
# Section order in the sidebar; Tools (checks, Refresh, drivers, cleanup) is the Catalogue's own, never in Guided
$AkariCatalogueSections = 'Optimize', 'Customize', 'Hardware', 'Advanced', 'Tools'
$AkariCatalogueHeaders = @{ Hardware = 'Graphics & Hardware' }
# Category pages that also list what is on the PC, under their Tweaks (the search filters that list there): the page
# key -> the function that adds the list (UI\ServicesPage.ps1, UI\TasksPage.ps1) and the search box's placeholder
$AkariCatalogueLists = @{
    'Catalogue:Advanced/Services'        = @{ Show = 'Show-AkariServiceList'; Hint = 'Search services' }
    'Catalogue:Advanced/Scheduled tasks' = @{ Show = 'Show-AkariTaskList'; Hint = 'Search tasks' }
}

# the Tweaks the Catalogue lists: one-file Toggles, Choices and Actions (no Legacy, no Group Entries, not the Apps or
# OneClick Sections) whose Requires this PC meets
function Get-AkariCatalogueTweaks($Tweaks) {
    # foreach, not Where-Object: this runs over every loaded Tweak (5.1's pipeline is many times slower)
    @(foreach ($t in $Tweaks) {
        if (-not $t.Legacy -and -not $t.Group -and $t.Section -notin 'Apps', 'OneClick' -and $t.Kind -in 'Toggle', 'Choice', 'Action' -and
            (-not $t.Requires -or -not (Test-AkariRequirement $t))) { $t }
    })
}

# the whole Catalogue of $Tweaks, worked out once: @{ Tweaks (Get-AkariCatalogueTweaks); Pages (Get-AkariCataloguePages);
# ByPage (page key -> its Tweaks, in load order); Source; Count (the list it was made from and its size: the GUI makes it
# again when they change, Get-AkariCatalogueOf) }. Pure but for Test-AkariRequirement.
function New-AkariCatalogue($Tweaks) {
    $list = Get-AkariCatalogueTweaks $Tweaks
    $bySection = [ordered]@{}
    $byPage = @{}
    foreach ($t in $list) {
        if (-not $bySection.Contains([string]$t.Section)) { $bySection[[string]$t.Section] = [System.Collections.Generic.List[string]]::new() }
        $key = "$AkariCataloguePrefix$($t.Section)/$($t.Category)"
        if (-not $byPage.ContainsKey($key)) { $byPage[$key] = [System.Collections.Generic.List[object]]::new(); $bySection[[string]$t.Section].Add([string]$t.Category) }
        $byPage[$key].Add($t)
    }
    $sections = @($bySection.Keys)
    $ordered = @($AkariCatalogueSections | Where-Object { $_ -in $sections }) + @($sections | Where-Object { $_ -notin $AkariCatalogueSections } | Sort-Object)
    $pages = @(foreach ($s in $ordered) {
        $cats = @($bySection[$s] | Sort-Object)
        [pscustomobject]@{
            Section = $s
            Header  = $(if ($AkariCatalogueHeaders.ContainsKey($s)) { $AkariCatalogueHeaders[$s] } else { $s })
            Pages   = @(foreach ($c in $cats) { [pscustomobject]@{ Key = "$AkariCataloguePrefix$s/$c"; Category = $c } })
        }
    })
    @{ Tweaks = $list; Pages = $pages; ByPage = $byPage; Source = $Tweaks; Count = @($Tweaks).Count }
}

# the GUI's Catalogue of $Tweaks (the loaded list, $script:Tweaks): made once, again only when that list is another one
# or its size changed. Page switches and the search use it instead of filtering every Tweak again.
$script:AkariCatalogueMemo = $null
function Get-AkariCatalogueOf($Tweaks) {
    $m = $script:AkariCatalogueMemo
    if (-not $m -or -not [object]::ReferenceEquals($m.Source, $Tweaks) -or $m.Count -ne $Tweaks.Count) {
        $m = New-AkariCatalogue $Tweaks
        $script:AkariCatalogueMemo = $m
    }
    $m
}

# the sidebar: one entry per Section (Header) with its Category pages, in $AkariCatalogueSections order (unknown
# Sections after them, by name; Categories by name). @{ Section; Header; Pages = @(@{ Key; Category }) }
function Get-AkariCataloguePages($Tweaks) { (New-AkariCatalogue $Tweaks).Pages }

# the Tweaks of one page (its key), or every match of $Query (name or description) in sidebar order
function Get-AkariCatalogueList($Tweaks, [string]$Key, [string]$Query) { Find-AkariCatalogueList (New-AkariCatalogue $Tweaks) $Key $Query }

# the same from a Catalogue New-AkariCatalogue made: the search goes page by page, each page in its own order
function Find-AkariCatalogueList($Catalogue, [string]$Key, [string]$Query) {
    if ($Query) {
        $like = "*$Query*"
        return @(foreach ($s in $Catalogue.Pages) { foreach ($p in $s.Pages) {
            foreach ($t in $Catalogue.ByPage[$p.Key]) { if ("$($t.Name) $($t.Description)" -like $like) { $t } }
        } })
    }
    $hit = $Catalogue.ByPage[$Key]
    if ($null -ne $hit) { @($hit) }
}

# a Safe Mode Tweak was switched to $Mode (Apply / Revert) while its State is $State: it waits for Safe Mode, or, when
# that is where it already is (switched back before the restart), leaves the waiting list. $Pending: id -> @{ Mode;
# Value }. $Value: a Choice value other than Recommended, $Current: the Choice's value now.
function Set-AkariSafePending([hashtable]$Pending, $Tweak, [string]$State, [string]$Mode, $Value = $null, $Current = $null) {
    $done = if ($null -ne $Value) { $null -ne $Current -and (Test-AkariRegMatch $Current $Value) }
            else { ($Mode -eq 'Apply' -and $State -eq 'Optimized') -or ($Mode -eq 'Revert' -and $State -eq 'Default') }
    if ($done) { $Pending.Remove($Tweak.Id) } else { $Pending[$Tweak.Id] = @{ Mode = $Mode; Value = $Value } }
}

# the lines of the restart bar: Explorer changes and changes that need a PC restart, by count
function Get-AkariRestartBarText([int]$Explorer, [int]$Reboot) {
    $s = { param($n) if ($n -eq 1) { '' } else { 's' } }
    @(
        if ($Explorer) { "Explorer needs a restart to show $Explorer change$(& $s $Explorer)." }
        if ($Reboot) { "A restart finishes $Reboot change$(& $s $Reboot)." }
    )
}

# the State line of a card. $Busy: 'Waiting', 'Running', 'Reading' or ''
function Get-AkariCatalogueStateText($Tweak, [string]$State, [string]$Busy, [bool]$SafePending) {
    if ($Busy -eq 'Reading') { return 'Reading' + [char]0x2026 }
    if ($Busy -eq 'Waiting') { return 'Waiting' + [char]0x2026 }
    if ($Busy -eq 'Running') { return 'Applying' + [char]0x2026 }
    if ($SafePending) { return 'Waiting for Safe Mode' }
    if ($Tweak.Kind -eq 'Action') { return '' }
    switch ($State) { 'Optimized' { 'Optimized' } 'Default' { 'Windows default' } 'Custom' { 'Custom value' } default { 'State unknown' } }
}
