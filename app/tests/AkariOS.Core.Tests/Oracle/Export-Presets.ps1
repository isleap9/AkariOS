# The reference for the native PresetStore: the PowerShell app's Core\Presets.ps1 (with Log, Registry and Loader,
# dot-sourced: functions only) as PresetsOracleTests runs it. It resolves the built-in AkariOS preset against the real
# Tweaks (Apply and -Revert), reads -CsFile (a preset the native app saved) and saves -PsFile (one the native app reads).
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$CsFile, [Parameter(Mandatory)][string]$PsFile,
    [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
$AkariPresetDir = Join-Path ([IO.Path]::GetTempPath()) "akari-oracle-presets-$PID"
$AkariLogFile = Join-Path $AkariPresetDir 'akari.log'
foreach ($f in 'Log', 'Registry', 'Loader', 'Presets') { . (Join-Path $Src "Core\$f.ps1") }

function ConvertTo-PlainItem($i) {
    [ordered]@{ Id = $i.Id; Mode = $i.Mode; Value = $(if ($i.ContainsKey('Value')) { $i.Value } else { $null }); Phase = [int]$i.Phase }
}

$tweaks = (Get-AkariTweaks (Join-Path $Src 'Tweaks')).Tweaks
$preset = Read-AkariPreset (Join-Path $Src 'Presets\AkariOS.json') $true
$apply = Resolve-AkariPreset $preset $tweaks
$revert = Resolve-AkariPreset $preset $tweaks -Revert
$phases = @(Get-AkariPresetPhases $preset $apply.Items | ForEach-Object { [ordered]@{ Name = $_.Name; Boot = $_.Boot; Count = @($_.Items).Count } })

$cs = Read-AkariPreset $CsFile $false
$csEntries = @($cs.Entries | ForEach-Object { [ordered]@{ Id = $_.Id; Value = $_.Value; HasValue = $_.HasValue; Phase = $_.Phase } })

[void](Save-AkariPreset 'Saved by PowerShell' @(
    @{ Id = 'gaming-capture-off'; Mode = 'Apply' }
    @{ Id = 'some-toggle'; Mode = 'Revert' }
    @{ Id = 'win32-priority-separation'; Mode = 'Apply'; Value = 40 }
    @{ Id = 'advanced-services-off'; Mode = 'Apply'; Value = 'Manual' }
) 'from the PowerShell app' $PsFile)

$json = ConvertTo-Json -Depth 6 -Compress @{
    Apply = @($apply.Items | ForEach-Object { ConvertTo-PlainItem $_ }); Unknown = @($apply.Unknown)
    Revert = @($revert.Items | ForEach-Object { ConvertTo-PlainItem $_ })
    Phases = $phases
    CsName = $cs.Name; CsDescription = $cs.Description; CsEntries = $csEntries
}
[IO.File]::WriteAllText($Out, $json, [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $AkariPresetDir -Recurse -Force -ErrorAction SilentlyContinue
