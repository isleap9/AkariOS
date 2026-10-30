# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Clear Event Viewer Logs" (Ultimate
# Cleanup).
# Action: cleared events can't come back.
@{
    Id          = 'cleanup-event-logs'
    Name        = 'Clear the event logs'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Empties every Event Viewer log (Application, System, Security and the rest). Useful before tracking down a new problem; the old events are gone.'
    Confirm     = 'Clear every event log? The events in them are deleted for good.'
    Apply       = {
        $n = 0
        foreach ($log in @(Invoke-AkariWevtutil el)) { if ($log) { $null = Invoke-AkariWevtutil cl $log; $n++ } }
        "Cleared $n event logs"
    }
}
