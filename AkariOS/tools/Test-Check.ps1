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

# --- Test-DiskSpace: the REAL function, against the REAL filesystem ---
# This is a behavioural test, not a stub. It shipped a bug where line 161 read
# `$ps.Free` while line 160 assigned `$psd`: $ps was undefined, $ps.Free was
# null, null/1GB rounded to 0.0, and the blocking Fail branch fired with
# "Only 0 GB free on C:" on a machine with 240 GB free — which left the Install
# button permanently disabled. Nothing caught it because every assertion above
# only exercised STUBS and the check's own display string, never the number the
# function actually computes. Reading Get-PSDrive is read-only and touches no
# network, registry or WPF, so it is safe to run here.
Write-Host "Test-DiskSpace reports the real drive (regression: \$psd/\$ps typo)"
$ds = Test-DiskSpace
Assert "disk check returns a result"     ($null -ne $ds)
Assert "status is a valid value"         ($ds.Status -in @("Pass","Fail","Warning"))
Assert "message is not empty"            ($ds.Message.Length -gt 0)

# Whatever the machine's real free space is, the reported number must be
# consistent with it. Deriving the truth independently from .NET is the point:
# it catches a silently-nulled value that no stub could ever surface.
#
# The parse must accept BOTH decimal separators. [math]::Round renders under the
# current culture, and on a comma-decimal locale the message reads "240,3 GB
# free", so a [0-9.]-only pattern silently captures "3" instead of 240.3 and
# reports a false failure. That is not hypothetical - it is what this file did
# on first run.
$systemDriveName = $env:SystemDrive.TrimEnd('\',':')
$actualFreeGB    = [math]::Round((Get-PSDrive -Name $systemDriveName -PSProvider FileSystem).Free / 1GB, 1)
$dsMessage       = [string]$ds.Message

# The separator must be inferred from the MESSAGE, not from the expected value.
# The message is produced by the check under the machine's own culture, so a
# comma-decimal box renders "240,3 GB free" while an invariant-formatted expected
# value renders "240.3". Deriving the separator from the expected side therefore
# picks the wrong one and captures "3" instead of 240.3 - which is exactly the
# false failure this comment replaces.
$sep = if ($dsMessage -match '\d+,\d+\s*GB free') { ',' }
      elseif ($dsMessage -match '\d+\.\d+\s*GB free') { '\.' }
      else { '\.' }

$reportedGB = if ($dsMessage -match "([0-9]+$sep[0-9]+|[0-9]+)\s*GB free") {
    # Parse using the SAME culture the message was formatted with, so the value
    # round-trips. Comparing magnitudes makes the assertion culture-agnostic.
    [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::CurrentCulture)
} else { $null }

Assert "message contains a parseable GB figure" ($null -ne $reportedGB) `
    "Unparseable message: '$($ds.Message)' - a null Free renders as 0 and this test must see it"
Assert "reported GB matches the real filesystem" ($null -ne $reportedGB -and [math]::Abs($reportedGB - $actualFreeGB) -lt 0.2) `
    "Reported '$reportedGB' GB vs actual '$actualFreeGB' GB on $systemDriveName"
Assert "does not report 0 GB on a non-empty volume" ($reportedGB -gt 0) `
    "0 GB on a real volume is the exact signature of the nulled-\$ps bug"

# The typo shape itself, so a rename to $ps can never silently return.
$checkSrc = Get-Content -LiteralPath (Join-Path $Root "functions\public\Check.ps1") -Raw
Assert "assigns to \$psd"                 ($checkSrc -match '\$psd\s*=\s*Get-PSDrive')
Assert "reads \$psd.Free (not \$ps.Free)" ($checkSrc -match '\$psd\.Free\s*/\s*1GB')
Assert "Get-PSDrive is provider-filtered" ($checkSrc -match 'Get-PSDrive[^\r\n]*-PSProvider FileSystem')

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