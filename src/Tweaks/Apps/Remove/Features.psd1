# Names and Risk for the Windows features the feature Group lists. Name = the feature name (wildcards allowed).
# A feature not listed here shows its own name, Risk Caution.
@{
    Rows = @(
        @{ Name = 'Printing-PrintToPDFServices-Features'; Display = 'Microsoft Print to PDF'; Description = 'The "print to PDF" printer'; Risk = 'Caution' }
        @{ Name = 'Printing-XPSServices-Features'; Display = 'Microsoft XPS Document Writer'; Description = 'The XPS printer'; Risk = 'Safe' }
        @{ Name = 'Printing-Foundation-Features'; Display = 'Print and Document Services'; Description = 'Printer sharing and internet printing'; Risk = 'Caution' }
        @{ Name = 'Printing-Foundation-InternetPrinting-Client'; Display = 'Internet Printing Client'; Description = 'Print to printers over the internet'; Risk = 'Safe' }
        @{ Name = 'WorkFolders-Client'; Display = 'Work Folders Client'; Description = 'Sync folders from a work server'; Risk = 'Safe' }
        @{ Name = 'MicrosoftWindowsPowerShellV2Root'; Display = 'Windows PowerShell 2.0'; Description = 'The old PowerShell 2.0'; Risk = 'Safe' }
        @{ Name = 'MicrosoftWindowsPowerShellV2'; Display = 'Windows PowerShell 2.0 Engine'; Description = 'The old PowerShell 2.0 engine'; Risk = 'Safe' }
        @{ Name = 'MediaPlayback'; Display = 'Media Features'; Description = 'Windows Media Player Legacy and its playback parts'; Risk = 'Caution' }
        @{ Name = 'WindowsMediaPlayer'; Display = 'Windows Media Player Legacy'; Description = 'The old Windows Media Player'; Risk = 'Safe' }
        @{ Name = 'SmbDirect'; Display = 'SMB Direct'; Description = 'File sharing over RDMA network cards'; Risk = 'Safe' }
        @{ Name = 'SMB1Protocol*'; Display = 'SMB 1.0/CIFS File Sharing'; Description = 'Old, insecure file sharing'; Risk = 'Safe' }
        @{ Name = 'MSRDC-Infrastructure'; Display = 'Remote Differential Compression'; Description = 'Delta file sync for a few network apps'; Risk = 'Safe' }
        @{ Name = 'WCF-Services45'; Display = 'WCF Services'; Description = '.NET 4.8 networking services for business apps'; Risk = 'Caution' }
        @{ Name = 'WCF-TCP-PortSharing45'; Display = 'WCF TCP Port Sharing'; Description = 'Lets .NET business apps share a network port'; Risk = 'Caution' }
        # any other WCF feature (Windows 10's activation features): shown under its own name
        @{ Name = 'WCF-*'; Description = 'A .NET networking service for business apps'; Risk = 'Caution' }
        @{ Name = 'Internet-Explorer-Optional-*'; Display = 'Internet Explorer 11'; Description = 'Windows 10''s Internet Explorer'; Risk = 'Safe' }
        @{ Name = 'Microsoft-RemoteDesktopConnection'; Display = 'Remote Desktop Connection'; Description = 'Connect to other PCs with Remote Desktop'; Risk = 'Caution' }
        @{ Name = 'Recall'; Display = 'Recall'; Description = 'Windows Recall snapshots (Copilot+ PCs)'; Risk = 'Safe' }
        @{ Name = 'Microsoft-SnippingTool'; Display = 'Snipping Tool (legacy)'; Description = 'The old Snipping Tool'; Risk = 'Safe' }
        @{ Name = 'NetFx4-AdvSrvs'; Display = '.NET Framework 4.8 Advanced Services'; Description = 'Turn Windows features on or off breaks without it' }
        @{ Name = 'NetFx3'; Display = '.NET Framework 3.5'; Description = 'Older apps and games need it' }
        @{ Name = 'SearchEngine-Client-Package'; Display = 'Windows Search'; Description = 'Search breaks without it' }
        @{ Name = 'Windows-Defender*'; Display = 'Microsoft Defender'; Description = 'Defender breaks without it' }
        @{ Name = 'DirectPlay'; Display = 'DirectPlay'; Description = 'Old games need it' }
        @{ Name = 'LegacyComponents'; Display = 'Legacy Components'; Description = 'Old games need it (DirectPlay)' }
    )
}
