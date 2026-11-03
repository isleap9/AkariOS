# The reference for the native Selection (app/AkariOS.Core/Tweaks/Selection.cs): src\UI\Selection.ps1's
# Get-AkariConfirmText and Get-AkariChoiceLabel on every Tweak in src\Tweaks, written as JSON for
# SelectionOracleTests. Per Tweak: the question for Optimized and Default (a Toggle or Action), or for each Choice
# value in order then its Default (a Choice), with each value's label. Build 26100 (Resolve-AkariDefault's per-OS
# Defaults); nothing on this PC is read. Like Export-Tweaks.ps1, it loads the tweak files; no block in them runs.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Loader.ps1')
. (Join-Path $Src 'Core\Registry.ps1')
. (Join-Path $Src 'Core\System.ps1')
. (Join-Path $Src 'UI\Selection.ps1')
function Get-AkariOSBuild { 26100 }

$result = [ordered]@{}
foreach ($t in (Get-AkariTweaks (Join-Path $Src 'Tweaks')).Tweaks) {
    if ($t.Kind -eq 'Choice') {
        $def = Resolve-AkariDefault $t.Default
        $result[$t.Id] = [ordered]@{
            Confirm = @(@($t.Choices | ForEach-Object { Get-AkariConfirmText $t $_.Value }) + @(Get-AkariConfirmText $t $def) | ForEach-Object { if ($null -eq $_) { '' } else { $_ } })
            Labels  = @($t.Choices | ForEach-Object { Get-AkariChoiceLabel $t $_.Value })
        }
    } else {
        $result[$t.Id] = [ordered]@{
            Confirm = @(@((Get-AkariConfirmText $t 'Optimized'), (Get-AkariConfirmText $t 'Default')) | ForEach-Object { if ($null -eq $_) { '' } else { $_ } })
            Labels  = @()
        }
    }
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 10 -Compress), [Text.UTF8Encoding]::new($false))
