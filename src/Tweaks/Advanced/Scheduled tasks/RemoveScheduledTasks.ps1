# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 remove-tasks "Remove ALL Scheduled
# Tasks": every task but SvcRestartTask and MsCtfMonitor (text input) is unregistered.
# Action: a deleted task can't be put back (only a Windows repair or reset brings them back), so there is no Revert.
@{
    Id          = 'advanced-remove-scheduled-tasks'
    Name        = 'Remove all scheduled tasks'
    Section     = 'Advanced'
    Category    = 'Scheduled tasks'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Advanced'
    Guided      = $false
    Description = 'Deletes every scheduled task: Windows Update, Defender scans, maintenance, telemetry and your apps'' updaters. Only text input (MsCtfMonitor) and SvcRestartTask stay. It can''t be undone: only a Windows repair or reset brings the tasks back.'
    Confirm     = 'This deletes every scheduled task on this PC, including Windows Update, Defender and app updaters. It can''t be undone. Continue?'
    Apply       = {
        $n = Remove-AkariScheduledTasks 'SvcRestartTask', 'MsCtfMonitor'
        "Removed $n scheduled tasks"
    }
}
