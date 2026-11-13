# Shared by the Advanced > Features Toggles (dot-sourced by their blocks; after Chris Titus Tech's winutil, MIT,
# Copyright (c) 2022 CT Tech Group LLC: Invoke-WinUtilFeatureInstall). Each Toggle's features are in Features.psd1. A
# feature this Windows lacks is left out; DisablePending counts as off, EnablePending as on (a restart finishes it).

function Get-FeatureToggle([string]$Id) { (Import-PowerShellDataFile (Join-Path $PSScriptRoot 'Features.psd1'))[$Id] }

# the features of $Id on this Windows, each with its state now: @{ Name; Default; On }
function Get-FeatureToggleFeatures([string]$Id) {
    foreach ($f in (Get-FeatureToggle $Id).Features) {
        $s = Get-AkariFeatureState $f.Name
        if ($null -eq $s) { continue }
        @{ Name = $f.Name; Default = $f.Default -eq 'Enabled'; On = $s -in 'Enabled', 'EnablePending' }
    }
}

# Optimized = all on, Default = each as on a fresh Windows, else Custom; Unknown when none is on this Windows
function Get-FeatureToggleState([string]$Id) {
    $all = @(Get-FeatureToggleFeatures $Id)
    if (-not $all) { return 'Unknown' }
    if (-not @($all | Where-Object { -not $_.On })) { return 'Optimized' }
    if (-not @($all | Where-Object { $_.On -ne $_.Default })) { return 'Default' }
    'Custom'
}

# Windows Update's service turned on for $Work when it is off (AkariOS' Services: Off turns it off), put back after;
# a failure says $Hint
function Use-WindowsUpdate([scriptblock]$Work, [string]$Hint) {
    $off = "$((Get-AkariServices 'wuauserv' | Select-Object -First 1).Start)" -eq 'Disabled'
    if ($off) { Write-Log 'Windows Update: on for this install'; Set-AkariServiceStart 'wuauserv' 'Manual' }
    try { & $Work }
    catch { throw "$($_.Exception.Message.TrimEnd('.')). $Hint" }
    finally { if ($off) { Set-AkariServiceStart 'wuauserv' 'Disabled'; Write-Log 'Windows Update: off again' } }
}

# turns $Names on: with a Payload, from a Windows setup's sources\sxs when a drive has one, else through Windows Update
function Enable-FeatureToggleNames([string[]]$Names, [bool]$Payload) {
    if (-not $Names) { return }
    $source = if ($Payload) { Find-AkariWindowsSource } else { $null }
    if ($source) { Write-Log "Windows features: files from $source" }
    $work = { foreach ($n in $Names) { Write-Log "Turning on $n"; Enable-AkariFeature $n $(if ($source) { $source } else { '' }) } }
    if ($Payload -and -not $source) { Use-WindowsUpdate $work 'Connect to the internet, or mount a Windows ISO, and try again' }
    else { & $work }
}

# Apply: every feature of $Id on (the ones already on left as they are)
function Enable-FeatureToggle([string]$Id) {
    $t = Get-FeatureToggle $Id
    $all = @(Get-FeatureToggleFeatures $Id)
    foreach ($f in $t.Features) { if ($f.Name -notin @($all | ForEach-Object { $_.Name })) { Write-Log "Windows features: $($f.Name) is not on this Windows, skipped" } }
    if (-not $all) { throw 'none of its Windows features is on this Windows' }
    Enable-FeatureToggleNames @($all | Where-Object { -not $_.On } | ForEach-Object { $_.Name }) ([bool]$t.Payload)
}

# Revert: every feature of $Id as on a fresh Windows
function Reset-FeatureToggle([string]$Id) {
    $all = @(Get-FeatureToggleFeatures $Id)
    if (-not $all) { throw 'none of its Windows features is on this Windows' }
    foreach ($f in @($all | Where-Object { $_.On -and -not $_.Default })) { Write-Log "Turning off $($f.Name)"; Disable-AkariFeature $f.Name }
    Enable-FeatureToggleNames @($all | Where-Object { -not $_.On -and $_.Default } | ForEach-Object { $_.Name }) $false
}
