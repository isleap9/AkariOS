# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-java'
    Name        = 'Java (Temurin 21 JRE)'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Runtimes'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Java runtime, for Minecraft mods, launchers and tools.'
    Winget      = 'EclipseAdoptium.Temurin.21.JRE'
}
