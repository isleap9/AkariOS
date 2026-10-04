# Static test for the pre-flight layer. Exercises the AGGREGATION LOGIC with
# stub checks only — it never calls the real Test-* functions that touch the
# network, the registry, or CIM. No WPF window is created (Show-CheckResult and
# Set-InstallButtonEnabled are not invoked; only their text helpers are).
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\public\Check.ps1")

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

# --- New-CheckResult shape ---
Write-Host "New-CheckResult produces the uniform result shape"
$r = New-CheckResult -Name "X" -Status "Warning" -Message "m" -Blocking $false
Assert "has Name"     ($r.Name -eq "X")
Assert "has Status"   ($r.Status -eq "Warning")
Assert "has Message"  ($r.Message -eq "m")
Assert "Blocking set" ($r.Blocking -eq $false)

Write-Host "All six required check functions are defined"
foreach ($fn in @("Test-WindowsVersion","Test-AdminElevation","Test-InternetConnectivity",
                  "Test-DiskSpace","Test-PendingReboot","Test-PowerState","Invoke-PreFlightChecks")) {
    Assert "$fn defined" ([bool](Get-Command $fn -ErrorAction SilentlyContinue))
}

# --- Aggregation with stubs ---
function Stub-Pass    { New-CheckResult -Name "Stub pass"    -Status "Pass"    -Message "ok" }
function Stub-Fail    { New-CheckResult -Name "Stub fail"    -Status "Fail"    -Message "broken" }
function Stub-Warn    { New-CheckResult -Name "Stub warning" -Status "Warning" -Message "meh" -Blocking $false }
function Stub-FailNB  { New-CheckResult -Name "Stub non-blocking fail" -Status "Fail" -Message "meh" -Blocking $false }
function Stub-Throws  { throw "simulated check explosion" }

Write-Host "PREF-02: all pass -> CanInstall"
$agg = Invoke-PreFlightChecks -Checks @("Stub-Pass","Stub-Pass")
Assert "CanInstall true"  ($agg.CanInstall -eq $true)
Assert "PassCount 2"      ($agg.PassCount -eq 2)
Assert "Summary mentions 2 passed" ($agg.Summary -match '2 passed')

Write-Host "PREF-02: one blocking fail -> CanInstall false"
$agg = Invoke-PreFlightChecks -Checks @("Stub-Pass","Stub-Fail")
Assert "CanInstall false"  ($agg.CanInstall -eq $false)
Assert "FailCount 1"       ($agg.FailCount -eq 1)
Assert "BlockingFails has the reason" ($agg.BlockingFails[0].Message -eq "broken")

Write-Host "Warnings alone never block"
$agg = Invoke-PreFlightChecks -Checks @("Stub-Pass","Stub-Warn","Stub-Warn")
Assert "CanInstall true"   ($agg.CanInstall -eq $true)
Assert "WarningCount 2"    ($agg.WarningCount -eq 2)

Write-Host "A non-blocking Fail does not block"
$agg = Invoke-PreFlightChecks -Checks @("Stub-Pass","Stub-FailNB")
Assert "CanInstall true"   ($agg.CanInstall -eq $true)
Assert "FailCount 0"       ($agg.FailCount -eq 0)

Write-Host "A throwing check is downgraded to a Warning, never a pass"
$agg = Invoke-PreFlightChecks -Checks @("Stub-Pass","Stub-Throws")
Assert "CanInstall still true" ($agg.CanInstall -eq $true)
Assert "recorded as Warning"    ($agg.WarningCount -eq 1)
Assert "has the exception text" ($agg.Results[1].Message -match 'simulated check explosion')
Assert "not counted as pass"    ($agg.PassCount -eq 1)

Write-Host "A missing check name degrades to a Warning"
$agg = Invoke-PreFlightChecks -Checks @("Stub-Pass","No-Such-Check-9999")
Assert "CanInstall true"    ($agg.CanInstall -eq $true)
Assert "WarningCount 1"     ($agg.WarningCount -eq 1)
Assert "names the missing check" ($agg.Results[1].Message -match 'No-Such-Check-9999')

# --- UI-SPEC copy formatting ---
Write-Host "UI-SPEC row copy"
$d = Get-CheckDisplayText -Result (New-CheckResult -Name "Free disk space" -Status "Pass" -Message "40 GB free on C:")
Assert "pass row uses check mark"  ($d.Icon -eq [char]0x2713)
Assert "pass row shows name"       ($d.Title -match 'Free disk space')
Assert "pass row is green"         ($d.Color -eq "#66BB6A")

$d = Get-CheckDisplayText -Result (New-CheckResult -Name "Pending reboot" -Status "Fail" -Message "A reboot is pending.")
Assert "fail row uses cross"       ($d.Icon -eq [char]0x2717)
Assert "fail row says resolve"     ($d.Detail -match 'Resolve this before continuing\.$')
Assert "fail row is red"           ($d.Color -eq "#FF3333")

$d = Get-CheckDisplayText -Result (New-CheckResult -Name "Power state" -Status "Warning" -Message "On battery.")
Assert "warning row uses triangle" ($d.Icon -eq [char]0x26A0)
Assert "warning row says continue" ($d.Detail -match 'You can continue, but this may cause issues\.$')
Assert "warning row is amber"      ($d.Color -eq "#FFA726")

Write-Host "The check layer performs no writes"
$raw = Get-Content -LiteralPath (Join-Path $Root "functions\public\Check.ps1") -Raw
$src = [regex]::Replace([regex]::Replace($raw, '(?s)<#.*?#>', ''), '(?m)^\s*#.*$', '')
Assert "no New-Item"          ($src -notmatch 'New-Item(?!Property)')
Assert "no Set-ItemProperty"  ($src -notmatch 'Set-ItemProperty')
Assert "no Remove-Item"       ($src -notmatch 'Remove-Item')
Assert "no bcdedit"           ($src -notmatch 'bcdedit')
Assert "no Invoke-Expression" ($src -notmatch 'Invoke-Expression|\biex\b')

if ($fail -eq 0) { Write-Host "`nALL CHECK TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail CHECK TEST(S) FAILED"; exit 1 }