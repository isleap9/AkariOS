<#
    Test-RunspacePrelude.ps1 — regression test for the compiled-build runspace bug.

    THE BUG (confirmed on a VM)
        Invoke-RunInBackground builds its worker's prelude by reading function
        files off disk:

            Join-Path $PSScriptRoot "..\public"
            Join-Path $PSScriptRoot "..\private"

        In the SOURCE TREE those directories exist, so the prelude loads and
        every harness passes. In the COMPILED single-file akarios.ps1 they do not
        exist — $PSScriptRoot is the folder holding akarios.ps1 and there is no
        sibling public/ or private/. Test-Path fails for both, $loadLines stays
        empty, and the worker runspace is created with NO AkariOS functions.

        Consequences on the VM, all observed:
          - "Stage 1 engine process completed." logged 245 ms after launch,
            because Invoke-AkariOSEngine does not exist in the worker and the
            scriptblock fails without producing output.
          - Stage.ps1:289 ("Engine child process for ... exited with code N"),
            the first thing Invoke-AkariOSEngine logs unconditionally, never
            appeared in install.log at all.
          - winsux.ps1 never executed: C:\WINDOWS\Temp held only winsux.ps1
            (which AkariOS decoded), with no stepone.ps1 / steptwo.ps1 /
            reg.reg that winsux.ps1:28-29 downloads. No reboot, no Safe Mode.

        This also silently broke the Check tab's manual re-run, which uses the
        same runner.

    THE FIX
        The compiled script must carry its own function definitions as text and
        hand THOSE to the worker. Compile.ps1 already concatenates every function
        file into akarios.ps1; it now also embeds those same definitions as a
        base64 blob ($script:AkariOSFunctionSourceB64) which
        Invoke-RunInBackground decodes into its prelude when the on-disk
        directories are absent.

        Both paths are kept deliberately: the disk path still serves the source
        tree, so Test-Runspace.ps1 keeps testing what it always tested, and a
        new function exists so a test can pin the compiled path.

    Run:  powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/Test-RunspacePrelude.ps1
#>

param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
$fail = 0
$checks = 0

function Assert {
    param([string]$Label, [bool]$Condition, [string]$Detail = "")
    $script:checks++
    if ($Condition) { Write-Host "  PASS  $Label" }
    else {
        $script:fail++
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkGray }
        Write-Host "  FAIL  $Label" -ForegroundColor Red
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "The deployed artifact must not depend on a source tree on disk"
# ─────────────────────────────────────────────────────────────────────────────

$compiled = Join-Path $Root "akarios.ps1"
Assert "compiled akarios.ps1 exists" (Test-Path -LiteralPath $compiled) `
    "Run Compile.ps1 first - this test audits the artifact the user actually runs."

if (-not (Test-Path -LiteralPath $compiled)) { Write-Host "`nSKIPPED: nothing compiled yet."; exit 1 }

$src = Get-Content -LiteralPath $compiled -Raw

# The premise of the whole bug, asserted rather than assumed: if a sibling
# public/ or private/ ever existed next to akarios.ps1, the disk path would work
# by accident and this test would be measuring nothing.
Assert "compiled output has no on-disk function dirs to fall back on (premise)" `
    (-not (Test-Path -LiteralPath (Join-Path $Root "public"))) `
    "If a public/ dir exists here, this premise needs re-examining."

Assert "runner still tries the disk path first (source tree keeps working)" `
    ($src -match 'Join-Path \$PSScriptRoot "\.\.\\public"')

Assert "runner has a non-disk fallback" `
    ($src -match 'AkariOSFunctionSourceB64|AkariOSFunctionSource') `
    "Nothing supplies function definitions when the directories are missing."

# ── The embedded blob must exist, decode, and be COMPLETE ───────────────────
Assert "Compile.ps1 emits the function-source blob" `
    ($src -match 'AkariOSFunctionSourceB64') `
    "The compiled script carries no copy of its own functions for the worker."

# Extract the assignment and decode it. Written to tolerate single/double quotes
# and whitespace variation rather than pinning one exact formatting choice.
$m = [regex]::Match($src, '(?s)\$script:AkariOSFunctionSourceB64\s*=\s*["'']([^"'']{64,})["'']')
Assert "blob literal is present and non-trivial" $m.Success `
    "Expected a base64 payload of at least a few hundred characters."

if ($m.Success) {
    $decoded = ""
    try { $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($m.Groups[1].Value)) }
    catch { Assert "blob decodes as base64 UTF-8" $false $_.Exception.Message }

    Assert "blob decodes to PowerShell, not binary" ($decoded -match 'function\s+\w') `
        "Decoded text does not look like a PowerShell function library."

    # Every function AkariOS defines must be present in the worker's copy. A
    # partial embed is the failure mode that would break one caller at a time,
    # so this checks the FULL set rather than the one function that happened to
    # fail first on the VM.
    $defined = Get-ChildItem -Path (Join-Path $Root "functions\public"), (Join-Path $Root "functions\private") `
                            -File -Filter "*.ps1" -ErrorAction SilentlyContinue |
               ForEach-Object {
                   Select-String -LiteralPath $_.FullName -Pattern '^\s*function\s+([\w-]+)' -AllMatches |
                       ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
               } | Sort-Object -Unique

    $missing = @()
    foreach ($fn in $defined) {
        if ($decoded -notmatch ("(?m)^\s*function\s+" + [regex]::Escape($fn) + "\b")) { $missing += $fn }
    }
    Assert ("all {0} functions present in the embedded blob" -f $defined.Count) `
        ($missing.Count -eq 0) `
        ("Missing from worker copy: " + ($missing -join ", "))

    # The two that actually failed on the VM, called out by name so a future
    # partial-embed regression names the casualties rather than a count.
    foreach ($critical in @("Invoke-AkariOSEngine","Invoke-RunInBackground","Invoke-PreFlightChecks","Invoke-AkariOSStage")) {
        Assert "worker copy defines $critical" `
            ($decoded -match ("(?m)^\s*function\s+" + [regex]::Escape($critical) + "\b"))
    }

    # Script-scope constants are the trap Phase 2 already hit once: a worker that
    # gets functions but not $script: variables fails at run time, not load time.
    foreach ($const in @('AkariOSStage2Entry','AkariOSStage3Entry','AkariOSStageAssets','AkariOSCheckNames')) {
        Assert "worker copy carries `$$const" ($decoded -match ([regex]::Escape($const)))
    }
}

# ── The failure must be loud if the prelude ever comes up empty ─────────────
# Today it degrades silently: no functions, empty output, reported as success.
# A guard turns that class of bug into a log line instead of a stalled install.
Assert "empty prelude is detected and logged" `
    ($src -match '(?s)if\s*\(\s*-not\s+\$prelude\s*\).{0,400}?(Write-AkariOSLog|throw)') `
    "Without this, any future prelude failure looks exactly like a successful stage."

# ── A regression test must not assert on the SOURCE tree only ───────────────
# The reason this shipped: every harness dot-sourced the source tree, where the
# directories exist. Pin that at least one test audits the artifact.
$toolsWithCompiledChecks = @()
foreach ($t in Get-ChildItem -Path (Join-Path $Root "tools") -File -Filter "Test-*.ps1" -ErrorAction SilentlyContinue) {
    if ((Get-Content -LiteralPath $t.FullName -Raw) -match 'akarios\.ps1') { $toolsWithCompiledChecks += $t.Name }
}
Assert "at least one harness audits the compiled artifact" ($toolsWithCompiledChecks.Count -ge 1) `
    ("Harnesses referencing akarios.ps1: " + ($(if($toolsWithCompiledChecks.Count){$toolsWithCompiledChecks -join ", "}else{"none"})))

Write-Host ""
Write-Host ("{0} assertions, {1} failures" -f $checks, $fail)
if ($fail -gt 0) { exit 1 }
Write-Host "Runspace prelude OK" -ForegroundColor Green
exit 0