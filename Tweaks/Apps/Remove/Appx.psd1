# Store (AppX) apps for the appx Group (Appx.ps1), one row per package.
# Names, descriptions and Risk from Win11Debloat's Config/Apps.json (MIT, Raphire): safe = Safe, optional = Caution,
# unsafe = Advanced. Keep = FR33THY's keep-list (Ultimate "bloatware"): "Select all removable" leaves these alone.
@{
    Apps = @(
        @{ Name = 'Clipchamp.Clipchamp'; Display = 'Clipchamp'; Description = 'Video editor from Microsoft'; Risk = 'Safe' }
        @{ Name = 'Microsoft.3DBuilder'; Display = '3D Builder'; Description = 'Basic 3D modeling software'; Risk = 'Safe' }
        @{ Name = 'Microsoft.549981C3F5F10'; Display = 'Cortana'; Description = 'Microsoft Cortana voice assistant (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingFinance'; Display = 'Bing Finance'; Description = 'Finance news and tracking via Bing (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingFoodAndDrink'; Display = 'Bing Food And Drink'; Description = 'Recipes and food news via Bing (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingHealthAndFitness'; Display = 'Bing Health And Fitness'; Description = 'Health and fitness tracking/news via Bing (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingNews'; Display = 'Microsoft News'; Description = 'News aggregator app. Brings together breaking news, personalized article feeds, and global current events'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingSports'; Display = 'Bing Sports'; Description = 'Sports news and scores via Bing (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingTranslator'; Display = 'Bing Translator'; Description = 'Translation service via Bing'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingTravel'; Display = 'Bing Travel'; Description = 'Travel planning and news via Bing (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingWeather'; Display = 'Bing Weather'; Description = 'Weather forecast via Bing'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Windows.AIHub'; Display = 'Copilot+ AI Hub'; Description = 'Copilot+ AI Hub app (Windows 11 24H2+)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Copilot'; Display = 'Microsoft Copilot'; Description = 'AI assistant integrated into Windows'; Risk = 'Safe' }
        @{ Name = 'Microsoft.PCManager'; Display = 'Microsoft PC Manager'; Description = 'Microsoft PC Manager system cleanup and optimization tool (often preinstalled)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Getstarted'; Display = 'Get Started'; Description = 'Tips and introductory guide for Windows (Cannot be uninstalled in Windows 11)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Messaging'; Display = 'Messaging'; Description = 'Messaging app, often integrates with Skype (Largely discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Microsoft3DViewer'; Display = '3D Viewer'; Description = 'Viewer for 3D models'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MicrosoftJournal'; Display = 'Microsoft Journal'; Description = 'Digital note-taking app optimized for pen input'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MicrosoftOfficeHub'; Display = 'Office Hub'; Description = 'Hub to access Microsoft Office apps and documents (Precursor to Microsoft 365 app)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MicrosoftPowerBIForWindows'; Display = 'Power BI'; Description = 'Business analytics service client'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MicrosoftSolitaireCollection'; Display = 'Solitaire Collection'; Description = 'Collection of solitaire card games'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MicrosoftStickyNotes'; Display = 'Sticky Notes'; Description = 'Digital sticky notes app (Discontinued & replaced by OneNote)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.MixedReality.Portal'; Display = 'Mixed Reality Portal'; Description = 'Portal for Windows Mixed Reality headsets'; Risk = 'Safe' }
        @{ Name = 'Microsoft.NetworkSpeedTest'; Display = 'Network Speed Test'; Description = 'Internet connection speed test utility'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Office.OneNote'; Display = 'OneNote'; Description = 'Digital note-taking app (Universal Windows Platform version)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Office.Sway'; Display = 'Sway'; Description = 'Presentation and storytelling app'; Risk = 'Safe' }
        @{ Name = 'Microsoft.OneConnect'; Display = 'One Connect'; Description = 'Mobile Operator management app (Replaced by Mobile Plans)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Print3D'; Display = 'Print 3D'; Description = '3D printing preparation software'; Risk = 'Safe' }
        @{ Name = 'Microsoft.PowerAutomateDesktop'; Display = 'Power Automate'; Description = 'Desktop automation tool (RPA)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.SkypeApp'; Display = 'Skype (UWP)'; Description = 'Skype communication app, Universal Windows Platform version (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Todos'; Display = 'Microsoft To Do'; Description = 'To-do list and task management app'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Windows.DevHome'; Display = 'Dev Home'; Description = 'Developer dashboard and tool configuration utility (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsAlarms'; Display = 'Alarms & Clock'; Description = 'Alarms & Clock app'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsFeedbackHub'; Display = 'Feedback Hub'; Description = 'App for providing feedback to Microsoft on Windows'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsMaps'; Display = 'Windows Maps'; Description = 'Mapping and navigation app'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsSoundRecorder'; Display = 'Sound Recorder'; Description = 'Basic audio recording app'; Risk = 'Safe' }
        @{ Name = 'Microsoft.XboxApp'; Display = 'Xbox Console Companion'; Description = 'Old Xbox Console Companion App (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.ZuneVideo'; Display = 'Movies & TV'; Description = 'Microsoft Movies & TV app for playing previously purchased movies and TV shows on Windows'; Risk = 'Safe' }
        @{ Name = 'MicrosoftCorporationII.MicrosoftFamily'; Display = 'Family Safety'; Description = 'Family Safety App for managing family accounts and settings'; Risk = 'Safe' }
        @{ Name = 'MicrosoftCorporationII.QuickAssist'; Display = 'Quick Assist'; Description = 'Remote assistance tool'; Risk = 'Safe' }
        @{ Name = 'MicrosoftTeams'; Display = 'Microsoft Teams (Old)'; Description = 'Old Microsoft Teams personal (MS Store version)'; Risk = 'Safe' }
        @{ Name = 'MSTeams'; Display = 'Microsoft Teams (New)'; Description = 'New Microsoft Teams app (Work/School or Personal)'; Risk = 'Safe' }
        @{ Name = 'ACGMediaPlayer'; Display = 'ACG Media Player'; Description = 'Media player app'; Risk = 'Safe' }
        @{ Name = 'ActiproSoftwareLLC'; Display = 'Actipro Software'; Description = 'Potentially UI controls or software components, often bundled by OEMs'; Risk = 'Safe' }
        @{ Name = 'AdobeSystemsIncorporated.AdobePhotoshopExpress'; Display = 'Adobe Photoshop Express'; Description = 'Basic photo editing app from Adobe'; Risk = 'Safe' }
        @{ Name = 'Amazon.com.Amazon'; Display = 'Amazon'; Description = 'Amazon shopping app'; Risk = 'Safe' }
        @{ Name = 'AmazonVideo.PrimeVideo'; Display = 'Prime Video'; Description = 'Amazon Prime Video streaming service app'; Risk = 'Safe' }
        @{ Name = 'Asphalt8Airborne'; Display = 'Asphalt 8'; Description = 'Racing game'; Risk = 'Safe' }
        @{ Name = 'AutodeskSketchBook'; Display = 'Autodesk SketchBook'; Description = 'Digital drawing and sketching app'; Risk = 'Safe' }
        @{ Name = 'CaesarsSlotsFreeCasino'; Display = 'Caesars Slots'; Description = 'Casino slot machine game'; Risk = 'Safe' }
        @{ Name = 'COOKINGFEVER'; Display = 'Cooking Fever'; Description = 'Restaurant simulation game'; Risk = 'Safe' }
        @{ Name = 'CyberLinkMediaSuiteEssentials'; Display = 'CyberLink Media Suite'; Description = 'Multimedia software suite (often preinstalled by OEMs)'; Risk = 'Safe' }
        @{ Name = 'DisneyMagicKingdoms'; Display = 'Disney Magic Kingdoms'; Description = 'Disney theme park building game'; Risk = 'Safe' }
        @{ Name = 'Disney.37853FC22B2CE'; Display = 'Disney+'; Description = 'Disney+ streaming service app'; Risk = 'Safe' }
        @{ Name = 'DrawboardPDF'; Display = 'Drawboard PDF'; Description = 'PDF viewing and annotation app, often focused on pen input'; Risk = 'Safe' }
        @{ Name = 'Duolingo-LearnLanguagesforFree'; Display = 'Duolingo'; Description = 'Language learning app'; Risk = 'Safe' }
        @{ Name = 'FACEBOOK.FACEBOOK'; Display = 'Facebook'; Description = 'Facebook social media app'; Risk = 'Safe' }
        @{ Name = 'FarmVille2CountryEscape'; Display = 'FarmVille 2'; Description = 'Farming simulation game'; Risk = 'Safe' }
        @{ Name = 'Flipboard'; Display = 'Flipboard'; Description = 'News and social network aggregator styled as a magazine'; Risk = 'Safe' }
        @{ Name = 'HiddenCity'; Display = 'Hidden City'; Description = 'Hidden object puzzle adventure game'; Risk = 'Safe' }
        @{ Name = 'HULULLC.HULUPLUS'; Display = 'Hulu'; Description = 'Hulu streaming service app'; Risk = 'Safe' }
        @{ Name = 'iHeartRadio'; Display = 'iHeartRadio'; Description = 'Internet radio streaming app'; Risk = 'Safe' }
        @{ Name = 'Facebook.Instagram'; Display = 'Instagram'; Description = 'Instagram social media app'; Risk = 'Safe' }
        @{ Name = 'king.com.BubbleWitch3Saga'; Display = 'Bubble Witch 3'; Description = 'Puzzle game from King'; Risk = 'Safe' }
        @{ Name = 'king.com.CandyCrushSaga'; Display = 'Candy Crush Saga'; Description = 'Puzzle game from King'; Risk = 'Safe' }
        @{ Name = 'king.com.CandyCrushSodaSaga'; Display = 'Candy Crush Soda'; Description = 'Puzzle game from King'; Risk = 'Safe' }
        @{ Name = 'LinkedInforWindows'; Display = 'LinkedIn'; Description = 'LinkedIn professional networking app'; Risk = 'Safe' }
        @{ Name = 'MarchofEmpires'; Display = 'March of Empires'; Description = 'Strategy game'; Risk = 'Safe' }
        @{ Name = '4DF9E0F8.Netflix'; Display = 'Netflix'; Description = 'Netflix streaming service app'; Risk = 'Safe' }
        @{ Name = 'NYTCrossword'; Display = 'NYT Crossword'; Description = 'New York Times crossword puzzle app'; Risk = 'Safe' }
        @{ Name = 'OneCalendar'; Display = 'One Calendar'; Description = 'Calendar aggregation app'; Risk = 'Safe' }
        @{ Name = 'PandoraMediaInc'; Display = 'Pandora'; Description = 'Pandora music streaming app'; Risk = 'Safe' }
        @{ Name = 'PhototasticCollage'; Display = 'Phototastic Collage'; Description = 'Photo collage creation app'; Risk = 'Safe' }
        @{ Name = 'PicsArt-PhotoStudio'; Display = 'PicsArt'; Description = 'Photo editing and creative app'; Risk = 'Safe' }
        @{ Name = 'PolarrPhotoEditorAcademicEdition'; Display = 'Polarr Photo Editor'; Description = 'Photo editing app (Academic Edition)'; Risk = 'Safe' }
        @{ Name = 'flaregamesGmbH.RoyalRevolt'; Display = 'Royal Revolt'; Description = 'Tower defense / strategy game'; Risk = 'Safe' }
        @{ Name = 'Sidia.LiveWallpaper'; Display = 'Live Wallpaper'; Description = 'Live wallpaper app'; Risk = 'Safe' }
        @{ Name = 'SlingTV'; Display = 'Sling TV'; Description = 'Live TV streaming service app'; Risk = 'Safe' }
        @{ Name = 'SpotifyAB.SpotifyMusic'; Display = 'Spotify'; Description = 'Spotify music streaming app'; Risk = 'Safe' }
        @{ Name = 'BytedancePte.Ltd.TikTok'; Display = 'TikTok'; Description = 'TikTok short-form video app'; Risk = 'Safe' }
        @{ Name = 'TuneInRadio'; Display = 'TuneIn Radio'; Description = 'Internet radio streaming app'; Risk = 'Safe' }
        @{ Name = 'WinZipUniversal'; Display = 'WinZip'; Description = 'File compression and extraction utility (Universal Windows Platform version)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.BingSearch'; Display = 'Bing Search'; Description = 'Web Search from Microsoft Bing (Integrates into Windows Search)'; Risk = 'Caution' }
        @{ Name = 'Microsoft.GamingApp'; Display = 'Xbox Gaming App'; Description = 'Modern Xbox Gaming App, required for installing some PC games'; Risk = 'Caution' }
        @{ Name = 'Microsoft.GetHelp'; Display = 'Get Help'; Description = 'Required for some Windows 11 Troubleshooters and support interactions'; Risk = 'Advanced' }
        @{ Name = 'Microsoft.M365Companions'; Display = 'Microsoft 365 Companions'; Description = 'Microsoft 365 (Business) Calendar, Files and People mini-apps, these apps may be reinstalled if enabled by your Microsoft 365 admin'; Risk = 'Caution' }
        @{ Name = 'Microsoft.MSPaint'; Display = 'Paint 3D'; Description = 'Paint 3D (Modern paint application with 3D features)'; Risk = 'Caution' }
        @{ Name = 'Microsoft.OutlookForWindows'; Display = 'Outlook for Windows'; Description = 'New Outlook for Windows mail client'; Risk = 'Caution' }
        @{ Name = 'Microsoft.Paint'; Display = 'Paint'; Description = 'Classic Paint (Traditional 2D paint application)'; Risk = 'Caution'; Keep = $true }
        @{ Name = 'Microsoft.People'; Display = 'People'; Description = 'Required for & included with Mail & Calendar (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.RemoteDesktop'; Display = 'Remote Desktop'; Description = 'Remote Desktop client app'; Risk = 'Caution' }
        @{ Name = 'Microsoft.ScreenSketch'; Display = 'Snipping Tool'; Description = 'Snipping Tool (Screenshot and annotation tool)'; Risk = 'Caution' }
        @{ Name = 'Microsoft.StartExperiencesApp'; Display = 'Widgets Experience'; Description = 'This app powers Windows Widgets My Feed'; Risk = 'Caution' }
        @{ Name = 'Microsoft.Whiteboard'; Display = 'Whiteboard'; Description = 'Digital collaborative whiteboard app'; Risk = 'Caution' }
        @{ Name = 'Microsoft.Windows.Photos'; Display = 'Photos'; Description = 'Default photo viewing and basic editing app'; Risk = 'Caution'; Keep = $true }
        @{ Name = 'Microsoft.WindowsCalculator'; Display = 'Calculator'; Description = 'Calculator app'; Risk = 'Caution' }
        @{ Name = 'Microsoft.WindowsCamera'; Display = 'Camera'; Description = 'Camera app for using built-in or connected cameras'; Risk = 'Caution' }
        @{ Name = 'Microsoft.windowscommunicationsapps'; Display = 'Mail & Calendar'; Description = 'Mail & Calendar app suite (discontinued)'; Risk = 'Safe' }
        @{ Name = 'Microsoft.WindowsNotepad'; Display = 'Notepad'; Description = 'Notepad text editor app'; Risk = 'Caution'; Keep = $true }
        @{ Name = 'Microsoft.WindowsStore'; Display = 'Microsoft Store'; Description = 'Microsoft Store, WARNING: This app cannot be reinstalled easily if removed!'; Risk = 'Advanced' }
        @{ Name = 'Microsoft.WindowsTerminal'; Display = 'Windows Terminal'; Description = 'Default terminal app in windows 11 (Command Prompt, PowerShell, WSL), WARNING: Do not remove if you launched Win11Debloat from Windows Terminal, as this will cause the script to fail.'; Risk = 'Advanced' }
        @{ Name = 'Microsoft.Xbox.TCUI'; Display = 'Xbox TCUI Framework'; Description = 'UI framework, seems to be required for Microsoft Store, photos and certain games'; Risk = 'Advanced' }
        @{ Name = 'Microsoft.XboxGameOverlay'; Display = 'Xbox Game Overlay'; Description = 'Game overlay, required or useful for some games (part of Xbox Game Bar). Warning: Uninstalling this app may reduce game performance on PCs with certain modern processors.'; Risk = 'Caution' }
        @{ Name = 'Microsoft.XboxGamingOverlay'; Display = 'Xbox Gaming Overlay'; Description = 'Game overlay, required or useful for some games (part of Xbox Game Bar). Warning: Uninstalling this app may reduce game performance on PCs with certain modern processors.'; Risk = 'Caution' }
        @{ Name = 'Microsoft.XboxIdentityProvider'; Display = 'Xbox Identity Provider'; Description = 'Xbox sign-in framework, required for some games and Xbox services'; Risk = 'Advanced' }
        @{ Name = 'Microsoft.XboxSpeechToTextOverlay'; Display = 'Xbox Speech To Text'; Description = 'Accessibility feature required for some games, WARNING: This app cannot be reinstalled easily!'; Risk = 'Advanced' }
        @{ Name = 'Microsoft.YourPhone'; Display = 'Phone Link'; Description = 'Phone link (Connects Android/iOS phone to PC)'; Risk = 'Caution' }
        @{ Name = 'Microsoft.ZuneMusic'; Display = 'Media Player'; Description = 'Modern Media Player (Replaced Groove Music, plays local audio/video)'; Risk = 'Caution' }
        @{ Name = 'MicrosoftWindows.CrossDevice'; Display = 'Cross Device Experience'; Description = 'Phone integration within File Explorer, Camera and more (Part of Phone Link features)'; Risk = 'Caution' }
        @{ Name = 'MicrosoftWindows.Client.WebExperience'; Display = 'Windows Web Experience Pack'; Description = 'Helps deliver and update certain features, like Widgets, through the Microsoft Store'; Risk = 'Caution' }
        @{ Name = 'Microsoft.WidgetsPlatformRuntime'; Display = 'Widgets Platform Runtime'; Description = 'Runtime required for Windows Widgets to function'; Risk = 'Caution' }
        @{ Name = 'LGElectronics.LGMonitorApp'; Display = 'LG Monitor App'; Description = 'LG OEM software for controlling your LG monitor, Windows Update may silently reinstall this app if you have an LG monitor connected'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPAIExperienceCenter'; Display = 'HP AI Experience Center'; Description = 'HP OEM software, AI-enhanced features and support'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPConnectedMusic'; Display = 'HP Connected Music'; Description = 'HP OEM software for music (Potentially discontinued)'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPConnectedPhotopoweredbySnapfish'; Display = 'HP Connected Photo'; Description = 'HP OEM software for photos, integrated with Snapfish (Potentially discontinued)'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPDesktopSupportUtilities'; Display = 'HP Desktop Support Utilities'; Description = 'HP OEM software providing desktop support tools'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPEasyClean'; Display = 'HP Easy Clean'; Description = 'HP OEM software for system cleaning or optimization'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPFileViewer'; Display = 'HP File Viewer'; Description = 'HP OEM software for viewing specific file types'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPJumpStarts'; Display = 'HP JumpStarts'; Description = 'HP OEM software for tutorials, app discovery, or quick access to HP features'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPPCHardwareDiagnosticsWindows'; Display = 'HP PC Hardware Diagnostics'; Description = 'HP OEM software for PC hardware diagnostics'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPPowerManager'; Display = 'HP Power Manager'; Description = 'HP OEM software for managing power settings and battery'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPPrinterControl'; Display = 'HP Printer Control'; Description = 'HP OEM software for managing HP printers'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPPrivacySettings'; Display = 'HP Privacy Settings'; Description = 'HP OEM software for managing privacy settings'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPQuickDrop'; Display = 'HP QuickDrop'; Description = 'HP OEM software for quick file transfer between devices'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPQuickTouch'; Display = 'HP QuickTouch'; Description = 'HP OEM software, possibly for touch-specific shortcuts or controls'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPRegistration'; Display = 'HP Registration'; Description = 'HP OEM software for product registration'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPSupportAssistant'; Display = 'HP Support Assistant'; Description = 'HP OEM software for support, updates, and troubleshooting'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPSureShieldAI'; Display = 'HP Sure Shield AI'; Description = 'HP OEM security software, likely AI-based threat protection'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPSystemInformation'; Display = 'HP System Information'; Description = 'HP OEM software for displaying system information'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPWelcome'; Display = 'HP Welcome'; Description = 'HP OEM software providing a welcome experience or initial setup help'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.HPWorkWell'; Display = 'HP WorkWell'; Description = 'HP OEM software focused on well-being, possibly with break reminders or ergonomic tips'; Risk = 'Caution' }
        @{ Name = 'AD2F1837.myHP'; Display = 'myHP'; Description = 'HP OEM central hub app for device info, support, and services'; Risk = 'Caution' }
        @{ Name = 'E046963F.LenovoCompanion'; Display = 'Lenovo Vantage'; Description = 'Lenovo OEM hub app for device settings, updates, and support'; Risk = 'Caution' }
        @{ Name = 'LenovoCompanyLimited.LenovoVantageService'; Display = 'Lenovo Vantage Service'; Description = 'Background service component for Lenovo Vantage'; Risk = 'Caution' }
        @{ Name = 'DellInc.DellSupportAssistforPCs'; Display = 'Dell SupportAssist'; Description = 'Dell OEM support, diagnostic, and update tool'; Risk = 'Caution' }
        @{ Name = 'DellInc.DellDigitalDelivery'; Display = 'Dell Digital Delivery Services'; Description = 'Dell OEM software for delivering pre-purchased software'; Risk = 'Caution' }
        @{ Name = 'DellInc.DellMobileConnect'; Display = 'Dell Mobile Connect'; Description = 'Dell OEM app for linking Android/iOS phone to PC (superseded by Phone Link)'; Risk = 'Caution' }
        @{ Name = 'Microsoft.AV1VideoExtension'; Display = 'AV1 Video Extension'; Description = 'Plays AV1 video'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.AVCEncoderVideoExtension'; Display = 'AVC Encoder Video Extension'; Description = 'Encodes H.264 video'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.HEIFImageExtension'; Display = 'HEIF Image Extension'; Description = 'Opens HEIF/HEIC photos'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.HEVCVideoExtension'; Display = 'HEVC Video Extension'; Description = 'Plays H.265 video'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.MPEG2VideoExtension'; Display = 'MPEG-2 Video Extension'; Description = 'Plays MPEG-2 video'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.RawImageExtension'; Display = 'Raw Image Extension'; Description = 'Opens camera RAW photos'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.SecHealthUI'; Display = 'Windows Security'; Description = 'The Windows Security app (Defender settings)'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.VP9VideoExtensions'; Display = 'VP9 Video Extensions'; Description = 'Plays VP9 video'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.WebMediaExtensions'; Display = 'Web Media Extensions'; Description = 'Plays Ogg, Vorbis and Theora media'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'Microsoft.WebpImageExtension'; Display = 'WebP Image Extension'; Description = 'Opens WebP images'; Risk = 'Advanced'; Keep = $true }
        @{ Name = 'NVIDIACorp.NVIDIAControlPanel'; Display = 'NVIDIA Control Panel'; Description = 'NVIDIA graphics driver settings'; Risk = 'Advanced'; Keep = $true }
    )
}
