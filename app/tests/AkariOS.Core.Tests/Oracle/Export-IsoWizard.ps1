# The reference for the native ISO Builder wizard's pure parts (app/AkariOS.Core/Iso/IsoWizard.cs, IsoPlan.Steps):
# src\Core\Iso.ps1 and Iso\Image.ps1 on the shared Wizard data (Core\Iso\Wizard), the real Tweaks and the AkariOS
# preset, written back as JSON for IsoWizardOracleTests. Nothing touches the PC: no tweak block runs.
# -Paths: Tweak registry paths for Get-AkariIsoImagePath; -Builds: the image builds to bake for.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Paths, [Parameter(Mandatory)][string]$Builds)
$ErrorActionPreference = 'Stop'
$AkariIsoMarker = Join-Path ([IO.Path]::GetTempPath()) "akari-oracle-wizard-$([guid]::NewGuid().ToString('N')).json"
foreach ($f in 'Log', 'Registry', 'Trusted', 'AppSetup', 'System', 'Runner', 'Loader', 'Presets', 'Iso') { . (Join-Path $Src "Core\$f.ps1") }

$tweaks = @((Get-AkariTweaks (Join-Path $Src 'Tweaks')).Tweaks)
$preset = Find-AkariPreset 'AkariOS' (Join-Path $Src 'Presets')
$groups = @(Get-AkariIsoGroups)
$modes = @(Get-AkariIsoModes)
$list = { param($v) (@($v | Where-Object { $_ }) | ForEach-Object { "$_" }) -join ';' }
$result = [ordered]@{}

$result.Groups = @(foreach ($g in $groups) {
    "$($g.Id)|$($g.Name)|$($g.Description)|$($g.Kind)|$(if ($g.Risk) { $g.Risk } else { 'Safe' })|$([int]$g.Order)|$(& $list $g.Apps)|$(& $list $g.Features)|$(& $list $g.Capabilities)|$(& $list $g.Packages)|$(@($g.Registry | Where-Object { $_ }).Count)|$(& $list $g.RemoveKeys)|$(& $list $g['Remove'])|$(@($g.Boot | Where-Object { $_ }).Count)|$([bool]$g.PruneComponentStore)"
})
$result.Modes = @(foreach ($m in $modes) {
    $s = Get-AkariIsoSettings @{ Settings = $m.Settings }
    "$($m.Id)|$($m.Name)|$($m.Description)|$($m.Tag)|$([int]$m.Order)|$(& $list $m.Groups)|$($s.Compression)|$($s.Turbo)|$($s.CleanLeftovers)|$($s.LeaveOutNetFx3Files)|$([bool]$m.AkariOS)|$([bool]$m.Minimal)"
})
# each mode's app patterns, and its plan (the AkariOS mode with AkariOS, its bake and the first sign-in)
$result.Patterns = @(foreach ($m in $modes) { $pp = Get-AkariIsoAppPatterns (Get-AkariIsoGroupsPicked $m.Groups $groups) $tweaks; , @($pp | ForEach-Object { "$_" }) })
$result.Plans = @(foreach ($m in $modes) {
    $picked = Get-AkariIsoGroupsPicked $m.Groups $groups
    $c = @{ Edition = 'Windows 11 Pro'; Groups = @($m.Groups); AppPatterns = (Get-AkariIsoAppPatterns $picked $tweaks); Settings = $m.Settings }
    if ($m.AkariOS) { $c.AkariDir = 'C:\AkariOS'; $c.FirstSignIn = $true; $c.Bake = @((Get-AkariIsoBake $preset $tweaks 26100).InImage) }
    $p = New-AkariIsoPlan $c $picked
    , @($p | ForEach-Object { "$($_.Id)|$($_.Text)" })
})
$result.ImagePaths = @(foreach ($p in @([IO.File]::ReadAllLines($Paths))) { $r = Get-AkariIsoImagePath $p 'HKLM:\AkariIso_'; if ($null -eq $r) { '(none)' } else { $r } })
$result.Bakes = @(foreach ($b in @([IO.File]::ReadAllLines($Builds))) {
    $k = Get-AkariIsoBake $preset $tweaks ([int]$b)
    [ordered]@{ InImage = @($k.InImage | ForEach-Object { "$($_.Tweak.Id)=$(if ($null -eq $_.Value) { '' } else { "$($_.Value)" })" }); Later = @($k.Later) }
})
$result.Unknown = try { [void](Get-AkariIsoGroupsPicked @('SkipHardwareChecks', 'Nope') $groups); '' } catch { $_.Exception.Message }

[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 6 -Compress), [Text.UTF8Encoding]::new($false))
