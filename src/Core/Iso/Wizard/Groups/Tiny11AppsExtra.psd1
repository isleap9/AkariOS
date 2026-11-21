# ISO Builder removal group, ported from Tiny11 Builder (ntdevlabs, used with its developers' permission: ADR 0010,
# docs/permissions/tiny11builder.md) at commit 38f7ab6b1f177098c026a19b73ec84bca9c4b874: src/Tiny11Builder.Core/CleanupCatalog.cs,
# the bundled-app options Tiny11 removes and Tiny11 Core keeps ("paint", "camera", "terminal", "oem").
@{
    Name        = 'Paint, Camera, Terminal and OEM apps (Tiny11)'
    Description = 'Paint, 3D Viewer, OneNote, Camera, Windows Terminal and Intel / Dolby promotional apps. PowerShell, Command Prompt and camera drivers stay.'
    Kind        = 'Apps'
    Risk        = 'Caution'
    Order       = 4
    Apps        = @(
        'Microsoft.Paint', 'Microsoft.MSPaint', 'Microsoft.Microsoft3DViewer', 'Microsoft.Office.OneNote'
        'Microsoft.WindowsCamera'
        'Microsoft.WindowsTerminal'
        'AppUp.IntelManagementandSecurityStatus', 'DolbyLaboratories.DolbyAccess', 'DolbyLaboratories.DolbyDigitalPlusDecoderOEM'
    )
}
