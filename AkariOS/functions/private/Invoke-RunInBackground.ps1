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
    .PARAMETER ScriptBlock
        The code to run. Has access to $sync.
    .PARAMETER StatusStart
        Text shown in the status bar while the job is running.
    .PARAMETER StatusDone
        Text shown when the job completes successfully.
    #>
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$StatusStart = "Running...",
        [string]$StatusDone  = "Done."
    )

    if (Get-Command Set-Status -ErrorAction SilentlyContinue) { Set-Status $StatusStart "#AAAAAA" }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.ThreadOptions  = "ReuseThread"
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("sync", $sync)

    $ps = [powershell]::Create().AddScript($ScriptBlock)
    $ps.Runspace = $rs

    $handle = $ps.BeginInvoke()

    # Track runspace for cleanup
    $sync.runspaces.Add(@{ ps = $ps; handle = $handle; rs = $rs })

    # Completion watcher on a timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [timespan]::FromMilliseconds(300)
    $done  = $StatusDone
    $error = $null

    $timer.Add_Tick({
        if ($handle.IsCompleted) {
            $timer.Stop()
            try   { $error = $ps.EndInvoke($handle) } catch {}
            $rs.Close()
            $rs.Dispose()
            if ($error -and (Get-Command Write-AkariOSLog -ErrorAction SilentlyContinue)) {
                Write-AkariOSLog -Message ("Background job error: " + ($error | Out-String)) -Level "ERROR"
            }
            if (Get-Command Set-Status -ErrorAction SilentlyContinue) {
                if ($error) { Set-Status "Failed - see log" "#FF3333" } else { Set-Status $done "#66BB6A" }
            }
        }
    }.GetNewClosure())

    $timer.Start()
}