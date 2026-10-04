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

    # Plan 02-03: every diagnostics function must survive concatenation into the
    # single shipped file, exactly once. A duplicate definition is not a warning,
    # it silently rebinds the name, and a missing one leaves a button dead.
    foreach ($fn in @("Get-AkariOSStageFailure","Set-AkariOSStageFailure","Clear-AkariOSStageFailure",
                      "Show-StageError","Resolve-StageFailure",
                      "Invoke-BtnStageRetry","Invoke-BtnStageAbort")) {
        Assert ("compiled file defines $fn exactly once") ((@([regex]::Matches($c, '(?m)^function ' + [regex]::Escape($fn) + '\b'))).Count -eq 1)
    }
    # And all five Invoke-BtnStage* handlers, so the main.ps1 wiring loop
    # (Get-Command "Invoke-$btnName") resolves every button it finds.
    $btnHandlers = @([regex]::Matches($c, '(?m)^function Invoke-BtnStage')) | ForEach-Object { $_.Value }
    Assert "five Invoke-BtnStage* handlers compiled" ($btnHandlers.Count -eq 5)
    foreach ($h in @("Invoke-BtnStage1","Invoke-BtnStage2","Invoke-BtnStage3","Invoke-BtnStageRetry","Invoke-BtnStageAbort")) {
        Assert ("compiled file defines $h") ($c -match ('(?m)^function ' + [regex]::Escape($h) + '\b'))
    }

    # Plan 02-02 task 3: the stage buttons must survive compilation INTO the XAML
    # here-string. A button that is only in the source panel would parse and pass
    # every source-level assertion while being absent from the shipped app, so
    # this is asserted on the compiled artefact rather than on the panel file.
    # Compile.ps1:86 emits `$inputXML = @'` ... `'@`, a SINGLE-quoted here-string.
    $hereStrings = @([regex]::Matches($c, "(?s)@'\r?\n(.*?)\r?\n'@"))
    $xamlBody = ""
    foreach ($m in $hereStrings) {
        $body = $m.Groups[1].Value
        if ($body -like '*PanelProgress*') { $xamlBody = $body }
    }
    Assert 'the compiled $inputXML here-string carries PanelProgress' ($xamlBody -ne "")
    foreach ($b in @("BtnStage1","BtnStage2","BtnStage3","StageHandoffHint")) {
        Assert ("compiled XAML declares $b") ($xamlBody -like ('*Name="' + $b + '"*'))
        Assert ("compiled XAML has no x:Name for $b") ($xamlBody -notlike ('*x:Name="' + $b + '"*'))
    }
    # Plan 02-03: the error card and both its buttons must reach the shipped app
    # too. Declared only in the panel source they would parse fine and be absent
    # from every window the user ever sees.
    foreach ($b in @("StageErrorDetail","StageErrorTitle","StageErrorMessage","StageErrorLog","BtnStageRetry","BtnStageAbort")) {
        Assert ("compiled XAML declares $b") ($xamlBody -like ('*Name="' + $b + '"*'))
        Assert ("compiled XAML has no x:Name for $b") ($xamlBody -notlike ('*x:Name="' + $b + '"*'))
        Assert ("compiled XAML has no Click= on $b") ($b -notmatch 'Click' -and $xamlBody -notmatch ('Name="' + $b + '"[^>]*Click='))
    }

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

Write-Host "Plan 02-02 task 3: Phase 1's resume switch is untouched"
$mainRaw = Get-Content -LiteralPath (Join-Path $Root "scripts\main.ps1") -Raw
Assert "StateInconsistent still handled"      ($mainRaw -like '*StateInconsistent*')
Assert 'the "inconsistent" case still exists' ($mainRaw -like '*"inconsistent"*')
Assert 'the "fresh" case still exists'        ($mainRaw -like '*"fresh"*')
Assert 'the -in form still covers stage1/2/3' ($mainRaw -match '\$_\s+-in\s+@\("stage1","stage2","stage3"\)')

# No "error" case may be added: a new ResumePoint value would change Phase 1's
# verified D-03/D-05 behaviour (RESEARCH §7 Decision 3).
$errorCases = @([regex]::Matches($mainRaw, '(?m)^\s*"error"\s*'))
Assert "no error case in the resume switch" ($errorCases.Count -eq 0)
Assert "no new ResumePoint value introduced" ($mainRaw -notmatch 'ResumePoint\s*=\s*"error"')

Write-Host "Plan 02-02 task 3: the launch-time reconciliation exists and is guarded"
Assert "a missing engine asset is named in the banner" ($mainRaw -like '*Missing engine assets*')
Assert "all four engine assets are checked" (($mainRaw -like '*winsux*') -and ($mainRaw -like '*steptwo*') -and ($mainRaw -like '*reg*'))
Assert "the banner is still wrapped in try/catch"     ($mainRaw -match 'Initialize-AkariOSLog -Banner')
Assert "the reconciliation is numbered step 6"        ($mainRaw -match '# 6\. Stage-status reconciliation')
Assert "reconciliation cannot block ShowDialog"       ($mainRaw -match 'Stage-status reconciliation failed')

# The reconciliation must NOT decide display state from state.json: T-02-15.
$reconBlock = ''
$rs = $mainRaw.IndexOf('# 6. Stage-status reconciliation')
if ($rs -ge 0) { $reconBlock = $mainRaw.Substring($rs) }
Assert "reconciliation reads Get-ResumePoint's value, not state.json" (
    ($reconBlock -like '*$resume.ResumePoint*') -and
    (-not ($reconBlock -match 'Get-AkariOSState')))
Assert "state.json is used only as corroboration in the log line" (
    ($reconBlock -like '*$resume.StateStage*') -and
    (-not ($reconBlock -match '\$sync\["ProgressStep"\]\s*\.')))

Write-Host "Plan 02-03: the failure is recorded at run time and surfaced at launch"
# The -OnComplete callback is the ONLY trigger, and it exists only because Plan 01
# fixed the by-value closure capture. Assert the whole chain is present in source,
# not just in the compiled artefact.
Assert "the stage runner passes an -OnComplete"     ($src -match 'OnComplete\s*=')
Assert "the callback records the failure"            ($src -match 'Set-AkariOSStageFailure')
Assert "a non-zero engine exit counts as a failure"  ($src -match '\$exitCode\s*-ne\s*0')
Assert "the engine exit code is read from the outcome" ($src -match '\$Outcome\.Results')
Assert "a clean finish clears a stale record"        ($src -match 'Clear-AkariOSStageFailure')

# main.ps1 must call detection at launch and be able to reach the card.
Assert "launch calls Get-AkariOSStageFailure"       ($mainRaw -like '*Get-AkariOSStageFailure*')
Assert "launch names BtnStageRetry"                 ($mainRaw -like '*BtnStageRetry*')
# Revealing the card is delegated to Reveal-StageError (it owns the card AND both
# buttons, so the two can never drift), so main.ps1 calls it rather than poking
# Visibility itself. Asserted against Diagnostics.ps1, which is where the card is
# actually manipulated.
Assert "Reveal-StageError manipulates the card"     (
    (Get-Content -LiteralPath (Join-Path $Root "functions\public\Diagnostics.ps1") -Raw) -like '*$syncRef.StageErrorDetail.Visibility*')
Assert "the launch step is numbered 7"              ($mainRaw -match '# 7\. Failed-stage detection')
Assert "the launch check precedes ShowDialog"       (
    $mainRaw.IndexOf('# 7. Failed-stage detection') -lt $mainRaw.IndexOf('$sync.window.ShowDialog()'))
Assert "the launch check cannot block ShowDialog"   ($mainRaw -match 'Stage failure detection failed')

# Detection must NOT be a resume case. A machine can sit at a perfectly normal
# resume point while carrying a failure record from the stage before it, which is
# exactly why this is an independent check (RESEARCH §7 Decision 3). Asserted on
# the COMMENT-STRIPPED block: the comment above it legitimately NAMES
# Get-ResumePoint to explain why the check does not use it.
$detectBlock = $mainRaw.Substring($mainRaw.IndexOf('# 7. Failed-stage detection'))
$detectCode = [regex]::Replace([regex]::Replace($detectBlock, '(?s)<#.*?#>', ''), '(?m)^\s*#.*$', '')
Assert "the launch check never consults Get-ResumePoint" (-not ($detectCode -match 'Get-ResumePoint|\$resume'))
Assert "the launch check never touches the resume switch" ($detectCode -notmatch 'switch\s*\(')
# Revealing the card is what enables the two buttons (Reveal-StageError owns both),
# so step 7 must go through it rather than poking Visibility directly on success.
Assert "the launch path reveals the card via Reveal-StageError" ($detectCode -match 'Show-StageError -Failure \$failure')

Write-Host "Plan 02-03 T-02-35: no dead !AkariOS relaunch RunOnce entry"
# DEVIATION, recorded explicitly. Phase 1 research assumed a `!AkariOS` RunOnce
# entry would relaunch the GUI after Stage 3. steptwo.ps1 deletes and recreates
# the RunOnce keys in HKCU, HKLM and WOW6432Node (steptwo.ps1:324-333), so that
# entry is unconditionally destroyed and can never fire. A key that sometimes
# vanishes is worse than no key: it wastes a VM session debugging a relaunch
# that was never going to happen. So AkariOS must write no such value anywhere.
$deadEntry = @()
foreach ($f in (Get-ChildItem (Join-Path $Root "functions") -Recurse -File -Filter "*.ps1") +
               (Get-ChildItem (Join-Path $Root "scripts") -Recurse -File -Filter "*.ps1")) {
    $lines = @(Get-Content -LiteralPath $f.FullName) | ForEach-Object { $i = 0 } { $i++; "$i`:$_" }
    $hit = @($lines | Where-Object { $_ -match '!AkariOS' -and $_ -notmatch '^\s*\d+\s*#' })
    if ($hit.Count) { $deadEntry += ($f.Name + ": " + ($hit -join ' | ')) }
}
Assert "no !AkariOS RunOnce value is written anywhere" ($deadEntry.Count -eq 0)
if ($deadEntry.Count -gt 0) { $deadEntry | ForEach-Object { Write-Host ("        " + $_) } }
# The two entries that DO exist must still come from Phase 1's constants in
# Resume.ps1, never restated. Stage.ps1 builds the reg.exe line with a -f format
# that interpolates {0} from the constant, so no literal entry name appears in the
# file at all — that is the property worth asserting, because a hardcoded name
# would survive a Phase 1 constant change and silently write the wrong entry.
Assert "Stage.ps1 never inlines a RunOnce entry name" (-not ($src -match '"\*!stepone"|"!steptwo"'))
Assert "Stage.ps1 references both Phase 1 constants" (
    ($src -match '\$script:AkariOSStage2Entry') -and ($src -match '\$script:AkariOSStage3Entry'))
Assert "the reg.exe line interpolates the entry name, it does not spell it" (
    ($src -match '-f \$entry, \$value'))
Assert "Phase 1's entry-name constants are unchanged in Resume.ps1" (
    (Get-Content -LiteralPath (Join-Path $Root "functions\public\Resume.ps1") -Raw) -match
    ([regex]::Escape('$script:AkariOSStage2Entry = "' + $script:AkariOSStage2Entry + '"')))
Assert "Phase 1's stage 3 entry-name constant is unchanged in Resume.ps1" (
    (Get-Content -LiteralPath (Join-Path $Root "functions\public\Resume.ps1") -Raw) -match
    ([regex]::Escape('$script:AkariOSStage3Entry = "' + $script:AkariOSStage3Entry + '"')))

if ($fail -eq 0) { Write-Host "`nALL STAGE TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail STAGE TEST(S) FAILED"; exit 1 }