# ISO Builder removal group, ported from Tiny11 Builder (ntdevlabs, used with its developers' permission: ADR 0010,
# docs/permissions/tiny11builder.md) at commit 38f7ab6b1f177098c026a19b73ec84bca9c4b874: src/Tiny11Builder.Core/CleanupCatalog.cs,
# the bundled-app options Tiny11 and Tiny11 Core both remove; an app matches by its exact name.
@{
    Name        = 'Bundled apps (Tiny11)'
    Description = 'Copilot, Outlook and Mail, Teams, Xbox and Game Bar, News and Weather, Office promotions, Clipchamp, Solitaire, Phone Link, Feedback and Tips, Dev Home, People, To Do, Maps, Media Player, Clock, Recorder, Sticky Notes and Quick Assist.'
    Kind        = 'Apps'
    Risk        = 'Caution'
    Order       = 3
    Apps        = @(
        'Microsoft.Copilot', 'Microsoft.Windows.Copilot', 'Microsoft.549981C3F5F10'
        'Microsoft.OutlookForWindows', 'microsoft.windowscommunicationsapps'
        'MSTeams', 'MicrosoftTeams', 'Microsoft.Windows.Teams'
        'Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch'
        'Microsoft.MicrosoftOfficeHub', 'Microsoft.OfficePushNotificationUtility'
        'Clipchamp.Clipchamp'
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.YourPhone', 'Microsoft.Windows.CrossDevice'
        'Microsoft.WindowsFeedbackHub', 'Microsoft.GetHelp', 'Microsoft.Getstarted'
        'Microsoft.Windows.DevHome', 'Microsoft.PowerAutomateDesktop'
        'Microsoft.People', 'Microsoft.Todos', 'Microsoft.SkypeApp', 'MicrosoftCorporationII.MicrosoftFamily'
        'Microsoft.WindowsMaps', 'Microsoft.MixedReality.Portal'
        'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo'
        'Microsoft.WindowsAlarms', 'Microsoft.WindowsSoundRecorder', 'Microsoft.MicrosoftStickyNotes'
        'MicrosoftCorporationII.QuickAssist'
    )
}
