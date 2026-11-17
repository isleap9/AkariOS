# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "java8".
@{
    Id          = 'install-corretto-8'
    Name        = 'Amazon Corretto 8'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Languages & SDKs'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'Java 8 JDK (LTS).'
    Winget      = 'Amazon.Corretto.8.JDK'
}
