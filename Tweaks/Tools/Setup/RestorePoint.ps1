# One-click's steptwo.ps1 (isleap9/Akari-OS): a restore point of the finished setup; also AkariOS-Ultimate (FR33THY
# Ultimate) 6 Windows "Restore Point". In Tools since batch 2c; its id stays, the AkariOS preset ends with it.
# Action: nothing to undo.
@{
    Id          = 'oneclick-restore-point'
    Name        = 'Create a restore point'
    Section     = 'Tools'
    Category    = 'Setup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Safe'
    Description = 'Creates an "AkariOS setup" System Restore point now (System Protection is turned on if needed). Restore it from the menu (System Restore).'
    Apply       = {
        $r = New-AkariRestorePoint 'AkariOS setup'
        if (-not $r.Ok) { throw $r.Message }
    }
}
