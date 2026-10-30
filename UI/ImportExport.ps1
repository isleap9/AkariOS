# Import / Export settings (M5): the Home tile and the title bar menu's two items.
# Export: this PC's Tweak settings as a preset file (Core\Presets.ps1 Export-AkariSettings), read in the background job.
# Import: a preset file into the Guided Selection, then Install AkariOS > Guided on its Tweaks step (Review & Apply
# as usual); a copy goes to the user's presets, so Quick select lists it. Apps are not part of it.

# the file pickers (tests stub them): the chosen path, or $null
function Select-AkariSettingsFile([bool]$Save) {
    Add-Type -AssemblyName System.Windows.Forms
    $d = if ($Save) { [Windows.Forms.SaveFileDialog]::new() } else { [Windows.Forms.OpenFileDialog]::new() }
    $d.Filter = 'AkariOS settings (*.json)|*.json|All files (*.*)|*.*'
    if ($Save) { $d.FileName = "AkariOS settings $env:COMPUTERNAME $((Get-Date).ToString('yyyy-MM-dd')).json" }
    if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { $null }
}

# the Home tile: which way
function Show-AkariImportExport {
    $q = "Export saves the settings this PC has (every AkariOS tweak that is applied, and each choice) to a file.`n`n" +
         "Import loads such a file, or any preset, and opens it in Guided, where you review the changes before applying them.`n`n" +
         'Removed and installed apps are not part of it.'
    switch (Show-AkariDialog $q 'Import / Export settings' @('Cancel', 'Import...', 'Export...') 'None') {
        'Import...' { Start-AkariImport }
        'Export...' { Start-AkariExport }
    }
}

function Start-AkariExport {
    if ($script:Busy) { return }
    $path = Select-AkariSettingsFile $true
    if (-not $path) { return }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $shared = [hashtable]::Synchronized(@{ Path = $path; Version = $AkariVersion })
    # the job loads the tweaks itself: a script block must not cross runspaces
    $code = @"
`$loaded = Get-AkariTweaks $(& $q "$Root\Tweaks")
`$AkariShared.Result = Export-AkariSettings @(`$loaded.Tweaks) `$AkariShared.Path `$AkariShared.Version
"@
    $label = 'Exporting settings'
    Set-Busy $true $label
    Add-Log "$label to $path"
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = 'Export'
}

# called by the Shell timer when the Export job has ended
function Complete-AkariExport($Shared) {
    $r = $Shared.Result
    if (-not $r) { Show-AkariMessage "The settings could not be exported. The log has the details." 'Error' 'Export settings'; return }
    Add-Log "Exported $($r.Count) settings: $($r.Path)"
    Show-AkariMessage "Exported $($r.Count) settings to:`n`n$($r.Path)" 'Info' 'Export settings'
}

# reads a settings file (any preset) and opens it in Guided; $false when it could not be used
function Start-AkariImport {
    if ($script:Busy) { return }
    $path = Select-AkariSettingsFile $false
    if (-not $path) { return }
    $p = Read-AkariPreset $path $false
    if (-not $p -or -not @($p.Entries).Count) {
        Show-AkariMessage "This file has no AkariOS settings in it:`n`n$path" 'Error' 'Import settings'
        return
    }
    # a copy in the user's presets (Quick select lists it); one already there by that name is replaced
    try {
        New-Item $AkariPresetDir -ItemType Directory -Force | Out-Null
        $dest = Join-Path $AkariPresetDir (Split-Path $path -Leaf)
        if ((Resolve-Path -LiteralPath $path).Path -ne $dest) { Copy-Item -LiteralPath $path -Destination $dest -Force }
    } catch { Add-Log "Warning: the imported file was not copied to the presets ($($_.Exception.Message))" }
    Add-Log "Import: $path"
    Select-AkariPage 'Install AkariOS'
    $script:Mode = 'Guided'
    $script:Step = 1
    Show-AkariSteps
    Set-AkariQuickSelect $p
}
