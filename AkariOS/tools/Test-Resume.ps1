# Decision-table test for Get-ResumePoint. Every outside-world input is INJECTED,
# so this runs no bcdedit, reads no registry, and touches no ProgramData.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\private\State.ps1")
. (Join-Path $Root "functions\public\Resume.ps1")

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

function RO($s2, $s3) { [pscustomobject]@{ HasStage2 = $s2; HasStage3 = $s3; Found = @() } }
$stPending = [pscustomobject]@{ CurrentStage = 0; Status = "pending"; Progress = 0; CurrentAction = "" }
$stMid     = [pscustomobject]@{ CurrentStage = 1; Status = "running"; Progress = 40; CurrentAction = "x" }
$stDone    = [pscustomobject]@{ CurrentStage = 3; Status = "completed"; Progress = 100; CurrentAction = "" }

Write-Host "D-03: Safe Mode active -> resume Stage 2"
$r = Get-ResumePoint -Safeboot "minimal" -RunOnce (RO $true $true) -State $stPending
Assert "stage2"        ($r.ResumePoint -eq "stage2")
Assert "safeboot shown" ($r.Safeboot -eq "minimal")

Write-Host "D-03: normal boot + !steptwo pending -> resume Stage 3"
$r = Get-ResumePoint -Safeboot $null -RunOnce (RO $true $true) -State $stMid
Assert "stage3"        ($r.ResumePoint -eq "stage3")

Write-Host "D-03: no RunOnce, no safeboot -> fresh"
$r = Get-ResumePoint -Safeboot $null -RunOnce (RO $false $false) -State $stPending
Assert "fresh"         ($r.ResumePoint -eq "fresh")

Write-Host "D-03: *!stepone pending but not in Safe Mode -> Stage 1 never completed"
$r = Get-ResumePoint -Safeboot $null -RunOnce (RO $true $false) -State $stPending
Assert "stage1"        ($r.ResumePoint -eq "stage1")

Write-Host "D-05: Safe Mode set but only stage 3 pending -> inconsistent"
$r = Get-ResumePoint -Safeboot "minimal" -RunOnce (RO $false $true) -State $stPending
Assert "inconsistent"  ($r.ResumePoint -eq "inconsistent")
Assert "reason given"  ($r.Reason.Length -gt 0)

Write-Host "Completed state with no RunOnce entries -> fresh"
$r = Get-ResumePoint -Safeboot $null -RunOnce (RO $false $false) -State $stDone
Assert "fresh"         ($r.ResumePoint -eq "fresh")

Write-Host "A completed state never resumes mid-flow"
$r = Get-ResumePoint -Safeboot $null -RunOnce (RO $false $true) -State $stDone
Assert "RunOnce wins over completed state" ($r.ResumePoint -eq "stage3")

Write-Host "bcdedit value variants all read as Safe Mode"
foreach ($v in @("minimal", "network", "set")) {
    $r = Get-ResumePoint -Safeboot $v -RunOnce (RO $true $true) -State $stPending
    Assert "safeboot '$v' -> stage2" ($r.ResumePoint -eq "stage2")
}

Write-Host "Decision table is pure: repeated calls agree"
$a = Get-ResumePoint -Safeboot "minimal" -RunOnce (RO $true $true) -State $stPending
$b = Get-ResumePoint -Safeboot "minimal" -RunOnce (RO $true $true) -State $stPending
Assert "deterministic" ($a.ResumePoint -eq $b.ResumePoint -and $a.Reason -eq $b.Reason)

Write-Host "The bcdedit wrapper is read-only (no /set or /deletevalue invocation)"
# Strip BOTH comment forms first: the doc comments legitimately *mention* these
# commands while explaining that they are never called. We assert on invocations.
#   1. remove <# ... #> block comments (used by the docstrings)
#   2. remove # line comments
$raw = Get-Content -LiteralPath (Join-Path $Root "functions\public\Resume.ps1") -Raw
$src = [regex]::Replace($raw, '(?s)<#.*?#>', '')      # block comments
$src = [regex]::Replace($src, '(?m)^\s*#.*$', '')      # line comments
Assert "no 'bcdedit /set' invocation"  ($src -notmatch 'bcdedit(?:\.exe)?\s+/set')
Assert "no '/deletevalue' invocation"  ($src -notmatch 'deletevalue')
Assert "no bcdedit write verbs"         ($src -notmatch 'bcdedit(?:\.exe)?\s+/(set|deletevalue|boot)')
Assert "no New-ItemProperty"            ($src -notmatch 'New-ItemProperty')
Assert "no Set-ItemProperty"            ($src -notmatch 'Set-ItemProperty')
Assert "no Remove-ItemProperty"         ($src -notmatch 'Remove-ItemProperty')
Assert "only /enum is invoked"          ($src -match 'bcdedit(?:\.exe)?\s+/enum')

if ($fail -eq 0) { Write-Host "`nALL RESUME TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail RESUME TEST(S) FAILED"; exit 1 }