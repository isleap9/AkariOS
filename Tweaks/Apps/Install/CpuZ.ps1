# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-cpu-z'
    Name        = 'CPU-Z'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'CPU, memory and motherboard details.'
    Winget      = 'CPUID.CPU-Z'
}
