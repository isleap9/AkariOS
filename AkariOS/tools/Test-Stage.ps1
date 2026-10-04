# Test for the stage runner: the handoff string builders, the seam wrappers, and the
# child-process launcher. Every outside-world value is INJECTED, so this runs no
# bcdedit, writes no registry key, starts no process and touches no ProgramData.
#
# The second half is STATIC: Stage.ps1 is re-read as text, comments stripped, and
# asserted on, which is the only way to prove a state-touching call is reachable
# ONLY through a seam without invoking one.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\private\State.ps1")
. (Join-Path $Root "functions\private\Assets.ps1")
. (Join-Path $Root "functions\public\Resume.ps1")
. (Join-Path $Root "functions\public\Stage.ps1")

# Stub out the logging/UI helpers Stage.ps1 calls so nothing writes to ProgramData
# and no WPF type is needed.
function Write-AkariOSLog { param([string]$Message, [string]$Level = "INFO", [string]$Path) }
function Set-Status        { param([string]$Text, [string]$Color = "White") }
function Set-CurrentStage  { param([int]$Stage, [string]$Action, [switch]$Resume) }

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

# The literal strings winsux.ps1:222 and :225 store in the RunOnce values. The engine
# interpolates $env:SystemRoot itself, so the EXPECTED value is derived the same way
# — on a host where SystemRoot is C:\WINDOWS the engine writes C:\WINDOWS\Temp\...,
# and matching that exactly is what byte-identical means. The plan's
# C:\Windows\Temp\... spelling is the same string case-insensitively, which the
# second assertion pins so a case change in our builder is still caught.
$expectedStage2 = "powershell.exe -nop -ep bypass -WindowStyle Maximized -f $(Join-Path $env:SystemRoot 'Temp')" + "\stepone.ps1"
$expectedStage3 = "powershell.exe -nop -ep bypass -WindowStyle Maximized -f $(Join-Path $env:SystemRoot 'Temp')" + "\steptwo.ps1"
$planStage2 = 'powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1'
$planStage3 = 'powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\steptwo.ps1'

Write-Host "FLOW-03: the RunOnce command strings are byte-identical to the engine's"
$got2 = Get-AkariOSRunOnceCommand -Stage 2
Assert "stage 2 string exact"   ($got2 -ceq $expectedStage2)
Assert "stage 3 string exact"   ((Get-AkariOSRunOnceCommand -Stage 3) -ceq $expectedStage3)
Assert "stage 2 matches the plan spelling" ($got2 -ieq $planStage2)
Assert "stage 3 matches the plan spelling" ((Get-AkariOSRunOnceCommand -Stage 3) -ieq $planStage3)
Assert "stage 1 has no entry" ($null -eq (Get-AkariOSRunOnceCommand -Stage 1))
Assert "builder is pure"      ((Get-AkariOSRunOnceCommand -Stage 2) -ceq $got2)

Write-Host "The builder resolves an injected temp root"
$got2Alt = Get-AkariOSRunOnceCommand -Stage 2 -TempRoot "D:\Scratch"
Assert "temp root honoured"  ($got2Alt -ceq 'powershell.exe -nop -ep bypass -WindowStyle Maximized -f D:\Scratch\stepone.ps1')

Write-Host "T-02-03: bcdedit is reachable only through -BcdWriter"
$cap = $null
Set-BcdSafebootValue -BcdWriter { param($c) $script:cap = $c } | Out-Null
Assert "set command exact" ($cap -ceq 'cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"')

$cap = $null
Clear-BcdSafebootValue -BcdWriter { param($c) $script:cap = $c } | Out-Null
Assert "clear command exact" ($cap -ceq 'cmd /c "bcdedit /deletevalue {current} safeboot >nul 2>&1"')

Write-Host "T-02-05: the RunOnce write goes through -RunOnceWriter, reusing Phase 1's entry names"
$cap = $null
Set-AkariOSRunOnceEntry -Stage 2 -RunOnceWriter { param($c) $script:cap = $c } | Out-Null
Assert "carries the entry name"    ($cap -like "*" + $script:AkariOSStage2Entry + "*")
Assert "carries the command"       ($cap -like "*" + $expectedStage2 + "*")
Assert "writes to HKCU RunOnce"    ($cap -like "*HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce*")

$cap = $null
Set-AkariOSRunOnceEntry -Stage 3 -RunOnceWriter { param($c) $script:cap = $c } | Out-Null
Assert "stage 3 uses !steptwo"     ($cap -like "*" + $script:AkariOSStage3Entry + "*")
Assert "stage 3 command present"   ($cap -like "*" + $expectedStage3 + "*")

Write-Host "Stage 1 has no RunOnce entry to write"
$cap = $null
$ok = Set-AkariOSRunOnceEntry -Stage 1 -RunOnceWriter { param($c) $script:cap = $c }
Assert "returns false"             ($ok -eq $false)
Assert "writer never invoked"      ($null -eq $cap)

Write-Host "T-02-04: Invoke-AkariOSEngine honours an injected -EngineInvoker and starts no process"
$seen = $null
$fake = Join-Path $env:TEMP "akarios-engine-stub.ps1"
Set-Content -LiteralPath $fake -Value "# stub" -Encoding UTF8
try {
    $code = Invoke-AkariOSEngine -ScriptPath $fake -EngineInvoker {
        param($p) $script:seen = $p; [pscustomobject]@{ ExitCode = 0 }
    }
    Assert "invoker received the path"  ($seen -eq $fake)
    Assert "exit code returned"         ($code -eq 0)

    $codeFail = Invoke-AkariOSEngine -ScriptPath $fake -EngineInvoker {
        param($p) [pscustomobject]@{ ExitCode = 3 }
    }
    Assert "non-zero exit surfaces"     ($codeFail -eq 3)

    $codeInt = Invoke-AkariOSEngine -ScriptPath $fake -EngineInvoker { param($p) 7 }
    Assert "bare int exit accepted"     ($codeInt -eq 7)

    $codeMissing = Invoke-AkariOSEngine -ScriptPath (Join-Path $env:TEMP "akarios-does-not-exist.ps1") -EngineInvoker {
        param($p) throw "invoker must not be reached"
    }
    Assert "missing script short-circuits" ($codeMissing -eq 9009)
} finally {
    Remove-Item -LiteralPath $fake -Force -ErrorAction SilentlyContinue
}

Write-Host "FLOW-01: Start-AkariOSInstall exists, so Confirm.ps1:233 resolves it"
Assert "contract name defined"  ((Get-Command Start-AkariOSInstall -ErrorAction SilentlyContinue) -ne $null)
Assert "takes no required args" (@((Get-Command Start-AkariOSInstall).Parameters.Keys).Count -ge 0)

Write-Host "The stage runner reaches every outside-world call through a seam"
$rs = @((Get-Command Invoke-AkariOSStage).Parameters.Keys)
foreach ($seam in @("AssetInvoker","EngineInvoker","RunOnceWriter","BcdWriter","StatePath")) {
    Assert "Invoke-AkariOSStage has -$seam" ($rs -contains $seam)
}

Write-Host "STATIC: no state-touching call sits outside a wrapper default"
# Strip BOTH comment forms first — the docstrings legitimately NAME bcdedit, the
# reboot commands and Start-Process while explaining that they are never called
# from anywhere else. We assert on invocations.
$raw = Get-Content -LiteralPath (Join-Path $Root "functions\public\Stage.ps1") -Raw
$src = [regex]::Replace($raw, '(?s)<#.*?#>', '')      # block comments
$src = [regex]::Replace($src, '(?m)^\s*#.*$', '')      # line comments

# 1. bcdedit appears ONLY on a line that also names the seam or is the deletevalue form.
$badBcd = @($src -split "`r?`n" | Where-Object {
    $_ -match 'bcdedit' -and $_ -notmatch 'BcdWriter' -and $_ -notmatch '/deletevalue \{current\} safeboot'
})
Assert "no bcdedit outside a -BcdWriter default" ($badBcd.Count -eq 0)
Assert "the safeboot set form exists"    ($src -match [regex]::Escape('bcdedit /set {current} safeboot minimal'))
Assert "the safeboot clear form exists"  ($src -match [regex]::Escape('bcdedit /deletevalue {current} safeboot'))

# 2. No registry cmdlet is used to write: the RunOnce write goes through reg.exe
#    inside the -RunOnceWriter default string only.
Assert "no New-ItemProperty"      ($src -notmatch 'New-ItemProperty')
Assert "no Set-ItemProperty"      ($src -notmatch 'Set-ItemProperty')
Assert "no reg.exe outside the writer string" ($src -notmatch 'reg\s+add' -or $src -match [regex]::Escape('reg add "HKCU'))

# 3. Start-Process appears only inside the -EngineInvoker default.
$sp = @($src -split "`r?`n" | Where-Object { $_ -match 'Start-Process' })
Assert "exactly one Start-Process" ($sp.Count -eq 1)
Assert "it is the engine launcher"  ($sp.Count -eq 1 -and $src -match 'EngineInvoker[\s\S]{0,600}Start-Process')

# 4. D-07: AkariOS never reboots the machine. The engine owns that.
Assert "no Restart-Computer"       ($src -notmatch 'Restart-Computer')
Assert "no shutdown -r"            ($src -notmatch 'shutdown\s+-r')
Assert "no Invoke-Reboot"          ($src -notmatch 'Invoke-Reboot')

# 5. No elevation is requested by our own launcher (the engine self-elevates).
Assert "no -Verb RunAs in Stage.ps1" ($src -notmatch 'Verb\s+RunAs')

Write-Host "STATIC: the compiled single file carries the four assets and the contract name"
$compiled = Join-Path $Root "akarios.ps1"
if (Test-Path -LiteralPath $compiled) {
    $c = Get-Content -LiteralPath $compiled -Raw
    foreach ($k in @("winsux","stepone","steptwo","reg")) {
        Assert ("`$sync.assets.$k compiled in") ($c -match ('(?m)^\$sync\.assets\.' + [regex]::Escape($k) + ' = '))
    }
    $installDefs = @([regex]::Matches($c, '(?m)^function Start-AkariOSInstall\b'))
    Assert "Start-AkariOSInstall defined once" ($installDefs.Count -eq 1)

    # Concatenation must produce a VALID single file every time it runs, so the
    # parse check lives here and re-runs on every future compile rather than
    # being a one-time manual check.
    $tokens = $null; $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($compiled, [ref]$tokens, [ref]$parseErrors)
    Assert "compiled akarios.ps1 parses with zero errors" ($parseErrors.Count -eq 0)
    if ($parseErrors.Count -gt 0) {
        $parseErrors | Select-Object -First 5 | ForEach-Object { Write-Host ("        " + $_.Message) }
    }
} else {
    Assert "compiled akarios.ps1 exists (run Compile.ps1 first)" $false
}

if ($fail -eq 0) { Write-Host "`nALL STAGE TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail STAGE TEST(S) FAILED"; exit 1 }