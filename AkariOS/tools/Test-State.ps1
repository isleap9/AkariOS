# Static harness for the state functions. Dot-sources State.ps1 and exercises it
# against a SCRATCH directory — never %ProgramData%\AkariOS, never the registry.
# Safe to run on a live machine: no UI, no elevation, no boot config touched.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\private\State.ps1")

$scratch = Join-Path $env:TEMP ("akarios-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$statePath = Join-Path $scratch "state.json"

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

try {
    Write-Host "Get-AkariOSState on a missing file returns the default shape"
    $s = Get-AkariOSState -Path $statePath
    Assert "CurrentStage = 0"      ($s.CurrentStage -eq 0)
    Assert "Status = pending"      ($s.Status -eq "pending")
    Assert "Progress = 0"          ($s.Progress -eq 0)
    Assert "SchemaVersion = 1"     ($s.SchemaVersion -eq 1)
    Assert "passes validation"     (Test-AkariOSState $s)

    Write-Host "Set-AkariOSState round-trips through an atomic write"
    $null = Set-AkariOSState -Path $statePath -CurrentStage 2 -Status "running" -Progress 45 -CurrentAction "Downloading payloads"
    Assert "state.json exists"     (Test-Path -LiteralPath $statePath)
    Assert "no temp files left"    (@(Get-ChildItem -LiteralPath $scratch -Filter ".state.*.tmp" -Force).Count -eq 0)
    $r = Get-AkariOSState -Path $statePath
    Assert "CurrentStage = 2"      ($r.CurrentStage -eq 2)
    Assert "Status = running"      ($r.Status -eq "running")
    Assert "Progress = 45"         ($r.Progress -eq 45)
    Assert "CurrentAction kept"    ($r.CurrentAction -eq "Downloading payloads")

    Write-Host "Partial updates do not wipe other fields"
    $null = Set-AkariOSState -Path $statePath -Progress 80
    $r2 = Get-AkariOSState -Path $statePath
    Assert "Progress updated"      ($r2.Progress -eq 80)
    Assert "CurrentStage kept"     ($r2.CurrentStage -eq 2)
    Assert "CurrentAction kept"    ($r2.CurrentAction -eq "Downloading payloads")

    Write-Host "RebootPending flag persists"
    $null = Set-AkariOSState -Path $statePath -RebootPending $true
    Assert "RebootPending = true"  ((Get-AkariOSState -Path $statePath).RebootPending -eq $true)

    Write-Host "T-01-STATE: corrupt JSON falls back to the default, does not throw"
    Set-Content -LiteralPath $statePath -Value '{ this is not json' -Encoding UTF8
    $bad = Get-AkariOSState -Path $statePath
    Assert "corrupt file -> default" ($bad.CurrentStage -eq 0 -and $bad.Status -eq "pending")

    Write-Host "T-01-STATE: out-of-range values are rejected"
    Set-Content -LiteralPath $statePath -Value '{"SchemaVersion":1,"CurrentStage":9,"Status":"running","Progress":50,"CurrentAction":"x"}' -Encoding UTF8
    $parsed = (Get-Content -LiteralPath $statePath -Raw) | ConvertFrom-Json
    Assert "raw CurrentStage 9 rejected"       (-not (Test-AkariOSState $parsed))
    Assert "getter falls back to stage 0"      ((Get-AkariOSState -Path $statePath).CurrentStage -eq 0)

    Write-Host "T-01-STATE: unknown status is rejected"
    Set-Content -LiteralPath $statePath -Value '{"SchemaVersion":1,"CurrentStage":1,"Status":"weird","Progress":50,"CurrentAction":"x"}' -Encoding UTF8
    $parsed = (Get-Content -LiteralPath $statePath -Raw) | ConvertFrom-Json
    Assert "raw unknown status rejected"      (-not (Test-AkariOSState $parsed))
    Assert "getter falls back to status pending" ((Get-AkariOSState -Path $statePath).Status -eq "pending")

    Write-Host "T-01-STATE: valid Int64 JSON numbers round-trip"
    Set-Content -LiteralPath $statePath -Value '{"SchemaVersion":1,"CurrentStage":2,"Status":"running","Progress":70,"CurrentAction":"Applying tweaks"}' -Encoding UTF8
    $parsed = (Get-Content -LiteralPath $statePath -Raw) | ConvertFrom-Json
    Assert "Int64 numbers accepted"           (Test-AkariOSState $parsed)
    Assert "stage 2 read back"                ((Get-AkariOSState -Path $statePath).CurrentStage -eq 2)
    Assert "progress 70 read back"            ((Get-AkariOSState -Path $statePath).Progress -eq 70)

    Write-Host "T-01-STATE: missing required properties are rejected"
    Assert "missing CurrentStage rejected"    (-not (Test-AkariOSState ([pscustomobject]@{ SchemaVersion = 1; Status = "running" })))
    Assert "null state rejected"              (-not (Test-AkariOSState $null))

    Write-Host "Initialize-AkariOSState does not clobber an existing file"
    Remove-Item -LiteralPath $statePath -Force
    $null = Set-AkariOSState -Path $statePath -CurrentStage 3 -Status "completed" -Progress 100
    $null = Initialize-AkariOSState -Path $statePath
    Assert "existing stage preserved" ((Get-AkariOSState -Path $statePath).CurrentStage -eq 3)

    Write-Host "Initialize-AkariOSState creates the file when absent"
    Remove-Item -LiteralPath $statePath -Force
    $null = Initialize-AkariOSState -Path $statePath
    Assert "file recreated"         (Test-Path -LiteralPath $statePath)
    Assert "default stage 0"        ((Get-AkariOSState -Path $statePath).CurrentStage -eq 0)

    Write-Host "Reset-AkariOSState removes the file"
    Reset-AkariOSState -Path $statePath
    Assert "file gone"              (-not (Test-Path -LiteralPath $statePath))
} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -eq 0) { Write-Host "`nALL STATE TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail STATE TEST(S) FAILED"; exit 1 }