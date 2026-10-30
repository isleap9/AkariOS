# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'install-vcredist'
    Name        = 'Visual C++ Redistributables'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Runtimes'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Every Visual C++ runtime from 2005 to 2022, 32- and 64-bit. Most games need some of them.'
    Winget      = 'Microsoft.VCRedist.2005.x86',
                  'Microsoft.VCRedist.2005.x64',
                  'Microsoft.VCRedist.2008.x86',
                  'Microsoft.VCRedist.2008.x64',
                  'Microsoft.VCRedist.2010.x86',
                  'Microsoft.VCRedist.2010.x64',
                  'Microsoft.VCRedist.2012.x86',
                  'Microsoft.VCRedist.2012.x64',
                  'Microsoft.VCRedist.2013.x86',
                  'Microsoft.VCRedist.2013.x64',
                  'Microsoft.VCRedist.2015+.x86',
                  'Microsoft.VCRedist.2015+.x64'
}
