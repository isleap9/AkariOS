# Action: this update comes back with Windows Update, not through an Akari Revert.
# Ported from FR33THY Ultimate "bloatware" (legacy apps).
@{
    Id          = 'remove-update-for-x64'
    Name        = 'Update for x64-based Windows Systems'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Safe'
    Description = 'Windows 10''s installer update (it brings the PC Health Check and Windows 11 upgrade prompts).'
    Detect      = { -not (Get-AkariMsi '*Update for x64-based Windows Systems*') }
    Apply       = { Uninstall-AkariMsi '*Update for x64-based Windows Systems*' }
}
