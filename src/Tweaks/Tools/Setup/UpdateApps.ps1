# Ported from Chris Titus Tech's winutil (MIT), functions/public/Invoke-WPFInstallUpgrade.ps1 ("Upgrade all"), through
# Akari's own winget call (Update-AkariWingetPackages: one "winget upgrade --all"). Also the Downloads page's
# "Update all apps" button. The installs' After steps (updaters removed, startup entries) are not run again.
# Action: an update has no Default to go back to.
@{
    Id          = 'tools-update-apps'
    Name        = 'Update all apps'
    Section     = 'Tools'
    Category    = 'Setup'
    Kind        = 'Action'
    Button      = 'Update'
    Risk        = 'Safe'
    Confirm     = 'Update every app winget can update? This can take a while and some apps may close.'
    Description = 'Updates every app winget knows a newer version of, from every source (winget and the Microsoft Store), in one go. Pinned apps are left alone. An updated app may bring back its own updater or startup entry.'
    Apply       = { Update-AkariWingetPackages | Out-Null }
}
