# One-click's steptwo.ps1 (isleap9/Akari-OS): a restore point of the finished setup.
# Action: nothing to undo.
@{
    Id          = 'oneclick-restore-point'
    Name        = 'Restore point of the finished setup'
    Section     = 'OneClick'
    Category    = 'Finish'
    Kind        = 'Action'
    Risk        = 'Safe'
    Description = 'Creates an "AkariOS setup" restore point once everything is done.'
    Apply       = {
        $r = New-AkariRestorePoint 'AkariOS setup'
        if (-not $r.Ok) { throw $r.Message }
    }
}
