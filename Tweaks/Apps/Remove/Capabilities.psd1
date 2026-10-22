# Names and Risk for the Optional features (capabilities) the capability Group lists. Name = the capability name
# before its version (wildcards allowed). A capability not listed here shows its own name, Risk Caution.
@{
    Rows = @(
        @{ Name = 'App.StepsRecorder'; Display = 'Steps Recorder'; Description = 'Records the steps to reproduce a problem'; Risk = 'Safe' }
        @{ Name = 'App.Support.QuickAssist'; Display = 'Quick Assist (Windows 10)'; Description = 'Remote help from another PC'; Risk = 'Safe' }
        @{ Name = 'Browser.InternetExplorer'; Display = 'Internet Explorer mode'; Description = 'Old sites in Edge''s IE mode'; Risk = 'Safe' }
        @{ Name = 'MathRecognizer'; Display = 'Math Recognizer'; Description = 'Handwritten math input'; Risk = 'Safe' }
        @{ Name = 'Media.WindowsMediaPlayer'; Display = 'Windows Media Player Legacy'; Description = 'The old Windows Media Player'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Wallpapers.Extended'; Display = 'Extended Theme Content'; Description = 'Extra wallpapers'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Windows.PowerShell.ISE'; Display = 'Windows PowerShell ISE'; Description = 'The old PowerShell script editor'; Risk = 'Safe' }
        @{ Name = 'Microsoft.Windows.WordPad'; Display = 'WordPad'; Description = 'Basic word processor'; Risk = 'Safe' }
        @{ Name = 'OneCoreUAP.OneSync'; Display = 'Exchange ActiveSync and Internet Mail'; Description = 'Mail account sync for old mail apps'; Risk = 'Safe' }
        @{ Name = 'Print.Fax.Scan'; Display = 'Windows Fax and Scan'; Description = 'Faxing and scanning app'; Risk = 'Safe' }
        @{ Name = 'Print.Management.Console'; Display = 'Print Management'; Description = 'Printer server management console'; Risk = 'Safe' }
        @{ Name = 'Accessibility.Braille'; Display = 'Braille support'; Description = 'Braille displays for Narrator'; Risk = 'Safe' }
        @{ Name = 'Analog.Holographic.Desktop'; Display = 'Mixed Reality'; Description = 'Windows Mixed Reality headsets'; Risk = 'Safe' }
        @{ Name = 'App.WirelessDisplay.Connect'; Display = 'Wireless Display'; Description = 'Project another device to this PC'; Risk = 'Safe' }
        @{ Name = 'Hello.Face.*'; Display = 'Windows Hello Face'; Description = 'Face sign-in with an IR camera'; Risk = 'Caution' }
        @{ Name = 'DirectX.Configuration.Database'; Display = 'DirectX Configuration Database'; Description = 'Compatibility fixes some older games use'; Risk = 'Caution' }
        @{ Name = 'Microsoft.Windows.Sense.Client'; Display = 'Microsoft Defender for Endpoint'; Description = 'Business Defender sensor (Sense), not the antivirus. Windows 11 won''t remove it (a permanent package, 0x800f0825)'; Keep = $true }
        @{ Name = 'OpenSSH.Client'; Display = 'OpenSSH Client'; Description = 'The ssh command'; Risk = 'Caution' }
        @{ Name = 'Language.Basic'; Display = 'Language: typing'; Description = 'Spell checking and text prediction for a language'; Risk = 'Caution' }
        @{ Name = 'Language.Handwriting'; Display = 'Language: handwriting'; Description = 'Pen handwriting recognition for a language'; Risk = 'Safe' }
        @{ Name = 'Language.OCR'; Display = 'Language: text recognition'; Description = 'Text in images (Snipping Tool text actions, Photos)'; Risk = 'Caution' }
        @{ Name = 'Language.Speech'; Display = 'Language: speech recognition'; Description = 'Voice typing and speech recognition'; Risk = 'Safe' }
        @{ Name = 'Language.TextToSpeech'; Display = 'Language: text to speech'; Description = 'Voices for Narrator and read-aloud'; Risk = 'Caution' }
        @{ Name = 'Microsoft.Windows.Ethernet.Client*'; Display = 'Ethernet drivers'; Description = 'Network card drivers: keep them' }
        @{ Name = 'Microsoft.Windows.Wifi.Client*'; Display = 'Wi-Fi drivers'; Description = 'Wireless card drivers: keep them' }
        @{ Name = 'Microsoft.Windows.Notepad.System'; Display = 'Notepad (system)'; Description = 'The Notepad that opens .txt files from the system' }
        @{ Name = 'Microsoft.Windows.Notepad'; Display = 'Notepad (Windows 10)'; Description = 'Windows 10''s Notepad' }
        @{ Name = 'Microsoft.Windows.MSPaint'; Display = 'Paint (Windows 10)'; Description = 'Windows 10''s Paint' }
        @{ Name = 'NetFX3'; Display = '.NET Framework 3.5'; Description = 'Older apps and games need it' }
        @{ Name = 'VBSCRIPT'; Display = 'VBScript'; Description = 'Windows 11: some MSI installers break without it' }
        @{ Name = 'WMIC'; Display = 'WMIC'; Description = 'Monitoring tools break without it' }
        @{ Name = 'Windows.Client.ShellComponents'; Display = 'Shell components'; Description = 'Windows 10: the Snipping Tool breaks without it' }
    )
}
