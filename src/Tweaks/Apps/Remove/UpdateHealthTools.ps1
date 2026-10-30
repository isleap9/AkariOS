# Action: Update Health Tools come back with Windows Update, not through an Akari Revert.
# Ported from FR33THY Ultimate "bloatware" (legacy apps).
@{
    Id          = 'remove-update-health-tools'
    Name        = 'Microsoft Update Health Tools'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Safe'
    Description = 'Windows 10''s update "health" service (uhssvc) and its PLUGScheduler task.'
    Detect      = { -not (Get-AkariMsi '*Microsoft Update Health Tools*') -and -not (Test-Path 'HKLM:\SYSTEM\ControlSet001\Services\uhssvc') }
    Apply       = {
        Uninstall-AkariMsi '*Microsoft Update Health Tools*'
        Remove-Item 'HKLM:\SYSTEM\ControlSet001\Services\uhssvc' -Recurse -Force -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName 'PLUGScheduler' -Confirm:$false -ErrorAction SilentlyContinue
    }
}
