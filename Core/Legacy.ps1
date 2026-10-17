# Adapter for the 8 legacy Tweaks\*.ps1 files (Add-Tweak calls) while they are ported to one-file tweaks.
# Delete this file when the last category is ported (AkariOS-PLAN.md §11 step 3).
# Needs Core/Loader.ps1 (ConvertTo-AkariTweak).

$script:AkariLegacyTweaks = [System.Collections.Generic.List[object]]::new()
$script:AkariLegacyFile = $null

function Add-Tweak {
    param([string]$Id, [string]$Category, [string]$Name, [string]$Description,
          [ValidateSet('Safe', 'Caution', 'Advanced')][string]$Risk = 'Safe',
          [ValidateSet('Toggle', 'Action', 'Group', 'Console')][string]$Kind = 'Toggle',
          [string]$Button = 'Run', [object[]]$Actions, [string]$Confirm, [string]$Script,
          [scriptblock]$Apply, [scriptblock]$Revert, [scriptblock]$Detect, [scriptblock]$Check)
    # the old -Category is the page, which is a Section now
    $h = @{ Id = $Id; Section = $Category; Category = ''; Name = $Name; Description = $Description; Risk = $Risk; Kind = $Kind
            Button = $Button; Actions = $Actions; Confirm = $Confirm; Apply = $Apply; Revert = $Revert; Detect = $Detect; Check = $Check }
    $script:AkariLegacyTweaks.Add((ConvertTo-AkariTweak $h $script:AkariLegacyFile $true))
}

function Import-AkariLegacyTweaks([string]$TweaksRoot) {
    $script:AkariLegacyTweaks = [System.Collections.Generic.List[object]]::new()
    foreach ($f in Get-ChildItem $TweaksRoot -Filter *.ps1 -File | Sort-Object Name) {
        $script:AkariLegacyFile = $f.FullName
        . $f.FullName
    }
    $script:AkariLegacyTweaks
}
