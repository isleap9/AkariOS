function Invoke-RunInBackground {
    <#
    .SYNOPSIS
        Runs a scriptblock on a background runspace so the WPF UI stays responsive.
    .DESCRIPTION
        Ported from AkariTool/functions/private/Invoke-RunInBackground.ps1. $sync is
        injected into the runspace so the worker can marshal updates back through
        $sync.window.Dispatcher.
        The runspace is STA and reuses the thread; a DispatcherTimer watches the
        invocation handle and tears the runspace down when it completes.

        The runspace is built from an InitialSessionState that dot-sources every
        AkariOS function file. [runspacefactory]::CreateRunspace() uses the DEFAULT
        session state, where none of our functions exist — a worker could call
        nothing of ours, and a stage launch would have failed on its very first
        call to Invoke-AkariOSEngine.

        The job's result travels in a HASHTABLE, not plain locals. A scriptblock
        closure captures by VALUE, so the old `$done` / `$error` locals mutated
        inside the tick handler were invisible to the caller and EVERY job —
        including a failed one — was reported as "Done." Same trap Phase 1 hit and
        fixed in Show-ConfirmationGate with a state hashtable.
    .PARAMETER ScriptBlock
        The code to run. Has access to $sync and every AkariOS function.
    .PARAMETER StatusStart
        Text shown in the status bar while the job is running.
    .PARAMETER StatusDone
        Text shown when the job completes successfully.
    .PARAMETER OnComplete
        Optional callback invoked AFTER the status update, on both the success and
        the failure branch. Receives the outcome hashtable, so a caller reads .Done
        and .Error off it. This is how a caller learns how the job ended without
        capturing a local of its own, which would hit the by-value trap again.
        Guarded, so the runner still works when no callback is supplied.
    #>
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$StatusStart = "Running...",
        [string]$StatusDone  = "Done.",
        [scriptblock]$OnComplete
    )

    if (Get-Command Set-Status -ErrorAction SilentlyContinue) { Set-Status $StatusStart "#AAAAAA" }

    # Build the session state from our own function files, read at run time and
    # sorted, so a NEW function file is picked up with no edit here.
    #
    # Two things this had to get right, both proven by tools/Test-Runspace.ps1:
    #
    # 1. [runspacefactory]::CreateRunspace() uses the DEFAULT session state, where
    #    none of our functions exist — a worker could call nothing of ours, and a
    #    stage launch died on its very first call to Invoke-AkariOSEngine.
    #    There is no InitialSessionState.AddScript on PowerShell 5.1; adding each
    #    function as a SessionStateFunctionEntry does NOT work either, because it
    #    carries over the functions but silently DROPS every `$script:` variable —
    #    $script:AkariOSStage2Entry, $script:AkariOSStages, the asset table — which
    #    is how the RunOnce entry names went missing in the worker.
    #
    # 2. Dot-sourcing the files into the runspace is what actually works: the
    #    definitions AND their script-scope constants both land in the worker's
    #    scope, and an injected seam like -BcdWriter is honoured in there.
    $functionDirs = @(
        (Join-Path $PSScriptRoot "..\public"),
        (Join-Path $PSScriptRoot "..\private")
    )

    $loadLines = @()
    foreach ($dir in $functionDirs) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $files = Get-ChildItem -LiteralPath $dir -File -Filter "*.ps1" -ErrorAction SilentlyContinue |
                 Sort-Object Name
        foreach ($file in $files) {
            # Single-quote the path and double any embedded quote: these run inside
            # the worker, where $PSScriptRoot is the runspace's, not ours.
            $escaped = $file.FullName.Replace("'", "''")
            $loadLines += ('. "{0}"' -f $escaped)
        }
    }
    $prelude = ($loadLines -join "`n")

    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()

    $rs = [runspacefactory]::CreateRunspace($iss)
    $rs.ApartmentState = "STA"
    $rs.ThreadOptions  = "ReuseThread"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $sync)

    # The prelude runs FIRST inside the worker, so by the time the caller's
    # scriptblock runs, every AkariOS function and constant is in scope.
    $ps = [powershell]::Create()
    if ($prelude) { $null = $ps.AddScript($prelude) }
    $null = $ps.AddScript($ScriptBlock)
    $ps.Runspace = $rs

    $handle = $ps.BeginInvoke()

    # Track runspace for cleanup
    $sync.runspaces.Add(@{ ps = $ps; handle = $handle; rs = $rs })

    # Completion watcher on a timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [timespan]::FromMilliseconds(300)

    # Shared result — MUST be a reference type, see .DESCRIPTION. The closure below
    # captures this hashtable by reference, so a write inside the tick handler is
    # visible to the -OnComplete callback and, through it, to the caller.
    $outcome = @{ Done = $StatusDone; Error = $null }

    $timer.Add_Tick({
        if ($handle.IsCompleted) {
            $timer.Stop()
            try   { $outcome.Error = $ps.EndInvoke($handle) } catch { $outcome.Error = $_ }
            $rs.Close()
            $rs.Dispose()
            if ($outcome.Error -and (Get-Command Write-AkariOSLog -ErrorAction SilentlyContinue)) {
                Write-AkariOSLog -Message ("Background job error: " + ($outcome.Error | Out-String)) -Level "ERROR"
            }
            if (Get-Command Set-Status -ErrorAction SilentlyContinue) {
                if ($outcome.Error) { Set-Status "Failed - see log" "#FF3333" }
                else { Set-Status $outcome.Done "#66BB6A" }
            }
            # Hand the result back on BOTH branches. Guarded so the runner still
            # works when the caller supplies no callback.
            if ($OnComplete) {
                try { & $OnComplete $outcome } catch {
                    if (Get-Command Write-AkariOSLog -ErrorAction SilentlyContinue) {
                        Write-AkariOSLog -Message ("-OnComplete callback failed: " + ($_ | Out-String)) -Level "ERROR"
                    }
                }
            }
        }
    }.GetNewClosure())

    $timer.Start()
}