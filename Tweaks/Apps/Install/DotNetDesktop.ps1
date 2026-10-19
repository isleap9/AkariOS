# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-dotnet-desktop'
    Name        = '.NET Desktop Runtimes'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Runtimes'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = '.NET 6, 8, 9 and 10 for desktop apps and tools.'
    Winget      = 'Microsoft.DotNet.DesktopRuntime.6',
                  'Microsoft.DotNet.DesktopRuntime.8',
                  'Microsoft.DotNet.DesktopRuntime.9',
                  'Microsoft.DotNet.DesktopRuntime.10'
}
