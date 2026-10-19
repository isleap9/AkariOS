# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-process-lasso'
    Name        = 'Process Lasso'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Process priorities, CPU affinity and power plan rules.'
    Winget      = 'BitSum.ProcessLasso'
}
