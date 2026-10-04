<#
    Test-InstallingStatus.ps1 — regression test for the Phase 1 defect that made
    every "Could not persist progress" warning appear in install.log.

    THE BUG
        Progress.ps1:101 writes  -Status "installing"
        State.ps1:111 accepts    pending | running | completed | error

        "installing" is not in the ValidateSet, so Set-AkariOSState threw into
        its own catch on EVERY progress update. Within-stage position was never
        persisted, and install.log carried a WARN line on every single update:

            [WARN ] Could not persist progress: Cannot validate argument on
            parameter 'Status'. The argument "installing" does not belong to the
            set "pending,running,completed,error"...

    WHY "installing" IS THE CORRECT VALUE
        Cancel.ps1:55 gates the cancel button on it:
            if ($State.Status -ne "installing") { return $false }
        So "installing" is the intended status of an in-flight Stage 1, and the
        ValidateSet is the side that is wrong. Adding "running" to the caller
        instead would have silently disabled cancel for the whole install - a
        second bug hidden inside the fix for the first.

        This means cancel has never armed on a real install: Test-Cancel could
        pass by handing the function a hand-built object with Status="installing",
        which Set-AkariOSState could never have written. Nothing ever exercised
        the two halves together.

    Run: powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/Test-InstallingStatus.ps1
#>

param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
$fail = 0; $checks = 0
$scratch = Join-Path $env:TEMP ("akarios-inst-" + [guid]::NewGuid().ToString("N").Substring(0,8))

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

function Get-Src { param([string]$Rel) Get-Content -LiteralPath (Join-Path $Root $Rel) -Raw }

# Strip comments so prose naming "installing" cannot satisfy or break a match.
function Strip-Comments { param([string]$T)
    $t = [regex]::Replace($T, '(?s)<#.*?#>', '')
    [regex]::Replace($t, '(?m)^\s*#.*$', '')
}

New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
    # ── Load the REAL state and progress layers ──────────────────────────────
    . (Join-Path $Root "functions\private\State.ps1")
    . (Join-Path $Root "functions\public\Progress.ps1")
    . (Join-Path $Root "functions\public\Cancel.ps1")

    $statePath = Join-Path $scratch "state.json"

    Write-Host "Set-AkariOSState accepts the status the progress layer writes"
    $err = $null
    $w = $null
    try {
        $w = Set-AkariOSState -Path $statePath -CurrentStage 1 -Progress 42 `
                                -Status "installing" -CurrentAction "Downloading payloads" -ErrorAction Stop
    } catch { $err = $_ }
    Assert 'writing -Status "installing" does not throw' ($null -eq $err) `
        ("This is the exact exception seen in install.log: " + $err)
    Assert "the write actually landed" ($null -ne $w)

    $after = Get-AkariOSState -Path $statePath
    Assert "persisted Status is installing" ($after.Status -eq "installing") `
        ("Read back: '" + $after.Status + "'")
    Assert "persisted Progress"    ($after.Progress -eq 42)
    Assert "persisted CurrentStage" ($after.CurrentStage -eq 1)
    Assert "persisted CurrentAction" ($after.CurrentAction -eq "Downloading payloads")

    # ── The two halves must agree, which nothing tested before ───────────────
    Write-Host "Cancel arms on the status progress actually writes (SAFE-04)"
    $canCancel = Get-CanCancel -State $after -StatePath $statePath
    Assert "cancel is armed during an active Stage 1" ($canCancel -eq $true) `
        "Cancel.ps1:55 gates on Status -eq 'installing'. If the ValidateSet rejected " +
        "'installing', progress never persisted it and cancel could never arm."

    # A 'running' status must NOT arm cancel - that is the whole point of having
    # a distinct 'installing' value, and the reason the caller must not be
    # 'fixed' by swapping the literal instead.
    $runningState = Set-AkariOSState -Path $statePath -CurrentStage 1 -Progress 42 -Status "running"
    Assert "cancel refuses a plain 'running' status" `
        ((Get-CanCancel -State (Get-AkariOSState -Path $statePath) -StatePath $statePath) -eq $false) `
        "If 'running' armed cancel too, the two statuses are indistinguishable and 'installing' is redundant."

    # Reboot pending must still refuse, even with a live 'installing' status.
    $rebootState = Set-AkariOSState -Path $statePath -CurrentStage 1 -Progress 99 `
                                    -Status "installing" -RebootPending $true
    Assert "cancel refuses once the reboot is queued" `
        ((Get-CanCancel -State (Get-AkariOSState -Path $statePath) -StatePath $statePath) -eq $false)

    # ── The documented status vocabulary must match the ValidateSet exactly ───
    Write-Host "ValidateSet and the documented vocabulary agree"
    $stateSrc  = Strip-Comments (Get-Src "functions\private\State.ps1")
    $progSrc   = Strip-Comments (Get-Src "functions\public\Progress.ps1")
    $cancelSrc = Strip-Comments (Get-Src "functions\public\Cancel.ps1")

    $vs = [regex]::Match($stateSrc, 'ValidateSet\(([^)]*)\)[^\r\n]*\$Status')
    Assert "found the -Status ValidateSet" $vs.Success
    if ($vs.Success) {
        $allowed = @([regex]::Matches($vs.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        Assert "ValidateSet contains 'installing'" ($allowed -contains "installing") `
            ("Allowed: " + ($allowed -join ", "))

        # Every status literal the codebase WRITES must be accepted. This is the
        # general form of the bug: a new -Status value in any caller that the
        # ValidateSet does not list throws at run time and is swallowed by a catch.
        $written = @()
        foreach ($f in @("functions\public\Progress.ps1","functions\public\Stage.ps1","functions\public\Resume.ps1")) {
            $s = Strip-Comments (Get-Src $f)
            foreach ($m in [regex]::Matches($s, 'Set-AkariOSState[^|]*?-Status\s+"([^"]+)"')) {
                $written += $m.Groups[1].Value
            }
        }
        $written = $written | Sort-Object -Unique
        $rejected = @($written | Where-Object { $allowed -notcontains $_ })
        Assert ("every -Status literal written is accepted ({0} found: {1})" -f $written.Count, ($written -join ", ")) `
            ($rejected.Count -eq 0) `
            ("Rejected by the ValidateSet: " + ($rejected -join ", ") + ". Each one throws at run time.")

        # And every status the codebase READS must be one the ValidateSet allows,
        # otherwise the reader is waiting for a value nothing can ever write.
        $read = @()
        foreach ($m in [regex]::Matches($cancelSrc, '\$State\.Status\s+-ne\s+"([^"]+)"')) { $read += $m.Groups[1].Value }
        foreach ($m in [regex]::Matches((Strip-Comments (Get-Src "functions\public\Resume.ps1")), '\$State\.Status\s+-eq\s+"([^"]+)"')) { $read += $m.Groups[1].Value }
        $read = $read | Sort-Object -Unique
        $unreachable = @($read | Where-Object { $allowed -notcontains $_ })
        Assert ("every status READ is a status the writer can produce ({0} read: {1})" -f $read.Count, ($read -join ", ")) `
            ($unreachable.Count -eq 0) `
            ("Read but never writable: " + ($unreachable -join ", "))
    }

    Assert "progress layer still writes the installing status" `
        ($progSrc -match 'Set-AkariOSState[^\r\n]*-Status\s+"installing"')

    # ── The READ path must accept everything the WRITE path accepts ──────────
    # This is the half that a ValidateSet-only test misses. Test-AkariOSState
    # carries its OWN status list; while it omitted "installing",
    # Set-AkariOSState wrote the file successfully and then
    # Get-AkariOSState - on the very next read - judged that same file CORRUPT
    # and overwrote it with defaults. The write was not just rejected, it was
    # UNDONE, silently. Asserting only the ValidateSet passed while the round
    # trip was still broken.
    Write-Host "A round trip survives: write then read is not treated as corrupt"
    $rtPath = Join-Path $scratch "roundtrip.json"
    Set-AkariOSState -Path $rtPath -CurrentStage 2 -Progress 73 -Status "installing" -CurrentAction "Removing bloatware" | Out-Null
    $rt = Get-AkariOSState -Path $rtPath
    Assert "round-trip preserves Status"    ($rt.Status -eq "installing") `
        ("Read back '" + $rt.Status + "' - Test-AkariOSState rejected a file it had just written.")
    Assert "round-trip preserves Progress"  ($rt.Progress -eq 73) `
        ("Read back " + $rt.Progress + " - the file was treated as corrupt and replaced with defaults.")
    Assert "round-trip preserves Stage"     ($rt.CurrentStage -eq 2)
    Assert "round-trip preserves Action"    ($rt.CurrentAction -eq "Removing bloatware")

    # The file on disk must be unchanged by the read. A validator that rejects a
    # valid file does not merely return a default - Get-AkariOSState rewrites.
    $mtimeBefore = (Get-Item -LiteralPath $rtPath).LastWriteTimeUtc
    Start-Sleep -Milliseconds 1100
    $null = Get-AkariOSState -Path $rtPath
    $mtimeAfter = (Get-Item -LiteralPath $rtPath).LastWriteTimeUtc
    Assert "reading does not rewrite the state file" ($mtimeBefore -eq $mtimeAfter) `
        "A read that rewrites means the validator rejected valid state and the defaults were persisted."

    # Both status lists must agree, checked directly rather than inferred.
    $testSrc = Strip-Comments (Get-Src "functions\private\State.ps1")
    $validator = [regex]::Match($testSrc, '\$State\.Status\s+-notin\s+@\(([^)]*)\)')
    Assert "found the Test-AkariOSState status list" $validator.Success
    if ($validator.Success -and $vs.Success) {
        $allowedWrite = @([regex]::Matches($vs.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        $allowedRead  = @([regex]::Matches($validator.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        $writeOnly = @($allowedWrite | Where-Object { $allowedRead -notcontains $_ })
        Assert "validator accepts everything the ValidateSet accepts" ($writeOnly.Count -eq 0) `
            ("Accepted on write but rejected on read (file treated as corrupt): " + ($writeOnly -join ", "))
        $readOnly = @($allowedRead | Where-Object { $allowedWrite -notcontains $_ })
        Assert "validator accepts nothing the ValidateSet rejects" ($readOnly.Count -eq 0) `
            ("Accepted on read but unwritable: " + ($readOnly -join ", "))
    }
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("{0} assertions, {1} failures" -f $checks, $fail)
if ($fail -gt 0) { exit 1 }
Write-Host "Installing-status OK" -ForegroundColor Green
exit 0