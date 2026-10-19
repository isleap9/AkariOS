# Store apps the restore Group can download again. Name = the AppX package name (as in Tweaks\Apps\Remove\Appx.psd1),
# StoreId = its Microsoft Store product id (each checked with winget show --source msstore, Oct 2026).
# No Store id found for Solitaire, Xbox Identity Provider, Xbox TCUI, HEVC Video Extensions and Maps.
@{
    Rows = @(
        @{ Name = 'Microsoft.Windows.Photos'; Display = 'Photos'; StoreId = '9WZDNCRFJBH4'; Description = 'Photo viewer and editor'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsCalculator'; Display = 'Calculator'; StoreId = '9WZDNCRFHVN5'; Description = 'Calculator'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsCamera'; Display = 'Camera'; StoreId = '9WZDNCRFJBBG'; Description = 'Webcam app'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsAlarms'; Display = 'Clock'; StoreId = '9WZDNCRFJ3PR'; Description = 'Alarms, timers and focus sessions'; Risk = 'Safe' }
        @{ Name = 'Microsoft.ScreenSketch'; Display = 'Snipping Tool'; StoreId = '9MZ95KL8MR0L'; Description = 'Screenshots (Win + Shift + S)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Paint'; Display = 'Paint'; StoreId = '9PCFS5B6T72H'; Description = 'Paint'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsNotepad'; Display = 'Notepad'; StoreId = '9MSMLRH6LZF3'; Description = 'Notepad'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsSoundRecorder'; Display = 'Sound Recorder'; StoreId = '9WZDNCRFHWKN'; Description = 'Audio recorder'; Risk = 'Safe' }
        @{ Name = 'Microsoft.ZuneMusic'; Display = 'Media Player'; StoreId = '9WZDNCRFJ3PT'; Description = 'Music and video player'; Risk = 'Safe' }
        @{ Name = 'Microsoft.ZuneVideo'; Display = 'Movies & TV'; StoreId = '9WZDNCRFJ3P2'; Description = 'Video player'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsTerminal'; Display = 'Windows Terminal'; StoreId = '9N0DX20HK701'; Description = 'Terminal for PowerShell and cmd'; Risk = 'Safe' }
        @{ Name = 'Microsoft.GamingApp'; Display = 'Xbox'; StoreId = '9MV0B5HZVK9Z'; Description = 'Xbox app and PC Game Pass'; Risk = 'Safe' }
        @{ Name = 'Microsoft.XboxGamingOverlay'; Display = 'Xbox Game Bar'; StoreId = '9NZKPSTSNW4P'; Description = 'In-game overlay (Win + G)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.GamingServices'; Display = 'Gaming Services'; StoreId = '9MWPM2CQNLHN'; Description = 'Needed by Game Pass games'; Risk = 'Safe' }
        @{ Name = 'Microsoft.XboxDevices'; Display = 'Xbox Accessories'; StoreId = '9NBLGGH30XJ3'; Description = 'Xbox controller settings and updates'; Risk = 'Safe' }
        @{ Name = 'Clipchamp.Clipchamp'; Display = 'Clipchamp'; StoreId = '9P1J8S7CCWWT'; Description = 'Video editor'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Todos'; Display = 'Microsoft To Do'; StoreId = '9NBLGGH5R558'; Description = 'Lists and reminders'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MicrosoftStickyNotes'; Display = 'Sticky Notes'; StoreId = '9NBLGGH4QGHW'; Description = 'Notes on the desktop'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingWeather'; Display = 'Weather'; StoreId = '9WZDNCRFJ3Q2'; Description = 'MSN Weather'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingNews'; Display = 'News'; StoreId = '9WZDNCRFHVFW'; Description = 'Microsoft News'; Risk = 'Safe' }
        @{ Name = 'Microsoft.OutlookForWindows'; Display = 'Outlook'; StoreId = '9NRX63209R7B'; Description = 'The new Outlook (mail and calendar)'; Risk = 'Safe' }
        @{ Name = 'microsoft.windowscommunicationsapps'; Display = 'Mail and Calendar'; StoreId = '9WZDNCRFHVQM'; Description = 'The old Mail and Calendar apps'; Risk = 'Safe' }
        @{ Name = 'MSTeams'; Display = 'Microsoft Teams'; StoreId = 'XP8BT8DW290MPQ'; Description = 'Chat and meetings'; Risk = 'Safe' }
        @{ Name = 'Microsoft.YourPhone'; Display = 'Phone Link'; StoreId = '9NMPJ99VJBWV'; Description = 'Your phone''s texts, calls and photos on the PC'; Risk = 'Safe' }
        @{ Name = 'Microsoft.GetHelp'; Display = 'Get Help'; StoreId = '9PKDZBMV1H3T'; Description = 'Microsoft support app'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsFeedbackHub'; Display = 'Feedback Hub'; StoreId = '9NBLGGH4R32N'; Description = 'Send feedback to Microsoft'; Risk = 'Safe' }
        @{ Name = 'Microsoft.PowerAutomateDesktop'; Display = 'Power Automate'; StoreId = '9NFTCH6J7FHV'; Description = 'Desktop automation'; Risk = 'Safe' }
        @{ Name = 'MicrosoftCorporationII.QuickAssist'; Display = 'Quick Assist'; StoreId = '9P7BP5VNWKX5'; Description = 'Remote help from another PC'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Copilot'; Display = 'Copilot'; StoreId = '9NHT9RB2F4HD'; Description = 'Microsoft Copilot'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MicrosoftOfficeHub'; Display = 'Microsoft 365 Copilot'; StoreId = '9WZDNCRD29V9'; Description = 'The Microsoft 365 (Office) app'; Risk = 'Safe' }
        @{ Name = 'MicrosoftCorporationII.MicrosoftFamily'; Display = 'Family Safety'; StoreId = '9PDJDJS743XF'; Description = 'Parental controls'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Windows.DevHome'; Display = 'Windows Advanced Settings'; StoreId = '9N8MHTPHNGVV'; Description = 'Developer settings (was Dev Home)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.AV1VideoExtension'; Display = 'AV1 Video Extension'; StoreId = '9MVZQVXJBQ9V'; Description = 'Plays AV1 video'; Risk = 'Safe' }
        @{ Name = 'Microsoft.VP9VideoExtensions'; Display = 'VP9 Video Extensions'; StoreId = '9N4D0MSMP0PT'; Description = 'Plays VP9 video'; Risk = 'Safe' }
        @{ Name = 'Microsoft.HEIFImageExtension'; Display = 'HEIF Image Extension'; StoreId = '9PMMSR1CGPWG'; Description = 'Opens HEIF/HEIC photos'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WebpImageExtension'; Display = 'WebP Image Extension'; StoreId = '9PG2DK419DRG'; Description = 'Opens WebP images'; Risk = 'Safe' }
        @{ Name = 'Microsoft.RawImageExtension'; Display = 'Raw Image Extension'; StoreId = '9NCTDW2W1BH8'; Description = 'Opens camera RAW photos'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WebMediaExtensions'; Display = 'Web Media Extensions'; StoreId = '9N5TDP8VCMHS'; Description = 'Plays Ogg, Vorbis and Theora media'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MPEG2VideoExtension'; Display = 'MPEG-2 Video Extension'; StoreId = '9N95Q1ZZPMH4'; Description = 'Plays MPEG-2 video'; Risk = 'Safe' }
    )
}
