# Catalogue (Optimize › Advanced, ADR 0005): every one-file Tweak on Section › Category pages, each change acting right
# away. This file is the pure part (no WPF): what is listed, the pages, search, the Safe Mode waiting list and the
# restart bar text. The page itself is UI\CataloguePage.ps1. Dot-sourced by Akari.ps1 before UI\Cards.ps1.

# page keys: 'Catalogue:<Section>/<Category>', and the search results page
$AkariCataloguePrefix = 'Catalogue:'
$AkariCatalogueSearch = 'Catalogue:Search'
# Section order in the sidebar; Tools (checks, Refresh, drivers, cleanup) is the Catalogue's own, never in Guided
$AkariCatalogueSections = 'Optimize', 'Customize', 'Hardware', 'Advanced', 'Tools'
$AkariCatalogueHeaders = @{ Hardware = 'Graphics & Hardware' }

# the Tweaks the Catalogue lists: one-file Toggles, Choices and Actions (no Legacy, no Group Entries, not the Apps or
# OneClick Sections) whose Requires this PC meets
function Get-AkariCatalogueTweaks($Tweaks) {
    @($Tweaks | Where-Object {
        -not $_.Legacy -and -not $_.Group -and $_.Section -notin 'Apps', 'OneClick' -and $_.Kind -in 'Toggle', 'Choice', 'Action' -and
        (-not $_.Requires -or -not (Test-AkariRequirement $_))
    })
}

# the sidebar: one entry per Section (Header) with its Category pages, in $AkariCatalogueSections order (unknown
# Sections after them, by name; Categories by name). @{ Section; Header; Pages = @(@{ Key; Category }) }
function Get-AkariCataloguePages($Tweaks) {
    $list = Get-AkariCatalogueTweaks $Tweaks
    $sections = @($list | ForEach-Object { $_.Section } | Select-Object -Unique)
    $ordered = @($AkariCatalogueSections | Where-Object { $_ -in $sections }) + @($sections | Where-Object { $_ -notin $AkariCatalogueSections } | Sort-Object)
    foreach ($s in $ordered) {
        $cats = @($list | Where-Object { $_.Section -eq $s } | ForEach-Object { $_.Category } | Select-Object -Unique | Sort-Object)
        [pscustomobject]@{
            Section = $s
            Header  = $(if ($AkariCatalogueHeaders.ContainsKey($s)) { $AkariCatalogueHeaders[$s] } else { $s })
            Pages   = @($cats | ForEach-Object { [pscustomobject]@{ Key = "$AkariCataloguePrefix$s/$_"; Category = $_ } })
        }
    }
}

# the Tweaks of one page (its key), or every match of $Query (name or description) in sidebar order
function Get-AkariCatalogueList($Tweaks, [string]$Key, [string]$Query) {
    $list = Get-AkariCatalogueTweaks $Tweaks
    if ($Query) {
        $order = @{}
        $i = 0
        foreach ($s in Get-AkariCataloguePages $Tweaks) { foreach ($p in $s.Pages) { $order["$($s.Section)/$($p.Category)"] = $i++ } }
        $hits = @($list | Where-Object { "$($_.Name) $($_.Description)" -like "*$Query*" })
        return @($hits | Sort-Object { $order["$($_.Section)/$($_.Category)"] })
    }
    $sc = $Key.Substring($AkariCataloguePrefix.Length)
    @($list | Where-Object { "$($_.Section)/$($_.Category)" -eq $sc })
}

# a Safe Mode Tweak was switched to $Mode (Apply / Revert) while its State is $State: it waits for Safe Mode, or, when
# that is where it already is (switched back before the restart), leaves the waiting list. $Pending: id -> Mode.
function Set-AkariSafePending([hashtable]$Pending, $Tweak, [string]$State, [string]$Mode) {
    $done = ($Mode -eq 'Apply' -and $State -eq 'Optimized') -or ($Mode -eq 'Revert' -and $State -eq 'Default')
    if ($done) { $Pending.Remove($Tweak.Id) } else { $Pending[$Tweak.Id] = $Mode }
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
