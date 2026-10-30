# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Remove pinned items in network and sound
# flyout". Windows marks an unpinned tile with an empty REG_NONE value, which reads back like a missing one, so the
# blocks check the value names.
@{
    Id          = 'taskbar-quick-settings-unpin'
    Name        = 'Fewer quick settings tiles'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Unpins Night light, Accessibility, Nearby sharing, Cast and Project from the network and sound flyout. Pin them back from the flyout''s edit button.'
    Detect      = {
        $names = 'BlueLightReduction', 'Accessibility', 'NearShare', 'Cast', 'ProjectL2' | ForEach-Object { "Microsoft.QuickAction.$_" }
        $k = Get-Item -LiteralPath (Resolve-AkariRegPath 'HKCU:\Control Panel\Quick Actions\Control Center\Unpinned') -ErrorAction SilentlyContinue
        $have = if ($k) { @($k.GetValueNames()) } else { @() }
        $n = @($names | Where-Object { $have -contains $_ }).Count
        if ($n -eq $names.Count) { 'Optimized' } elseif ($n -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $names = 'BlueLightReduction', 'Accessibility', 'NearShare', 'Cast', 'ProjectL2' | ForEach-Object { "Microsoft.QuickAction.$_" }
        foreach ($n in $names) { Set-Reg 'HKCU:\Control Panel\Quick Actions\Control Center\Unpinned' $n ([byte[]]@()) 'None' }
    }
    Revert      = {
        $names = 'BlueLightReduction', 'Accessibility', 'NearShare', 'Cast', 'ProjectL2' | ForEach-Object { "Microsoft.QuickAction.$_" }
        foreach ($n in $names) { Remove-Reg 'HKCU:\Control Panel\Quick Actions\Control Center\Unpinned' $n }
    }
}
