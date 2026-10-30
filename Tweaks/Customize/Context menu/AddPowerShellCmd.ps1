# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\powershellCmd.reg "Powershell and
# Cmd": elevated Command Prompt and PowerShell entries on folders, folder backgrounds, drives and libraries. Windows has
# none of these verb keys, so Revert deletes them (an empty LibraryFolder\Shell stays; it does nothing).
$c = 'HKLM:\SOFTWARE\Classes'
$cmd = 'PowerShell.exe -windowstyle hidden -Command "Start-Process cmd.exe -ArgumentList ''/s,/k,pushd,%V'' -Verb RunAs"'
$ps = 'PowerShell.exe -windowstyle hidden -Command "Start-Process cmd.exe -ArgumentList ''/s,/c,pushd %V && powershell'' -Verb RunAs"'
$verb = { param($k, $label, $icon, $command)
    @{ Path = $k; Name = '(default)'; Type = 'String'; Value = $label; Default = $null }
    @{ Path = $k; Name = 'NoWorkingDirectory'; Type = 'String'; Value = ''; Default = $null }
    @{ Path = $k; Name = 'NeverDefault'; Type = 'String'; Value = ''; Default = $null }
    @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = $icon; Default = $null }
    @{ Path = "$k\command"; Name = '(default)'; Type = 'String'; Value = $command; Default = $null }
    @{ Path = $k; Value = 'Key'; Default = $null }
}
@{
    Id          = 'context-add-powershell-cmd'
    Name        = 'Add elevated Command Prompt and PowerShell to folders'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking a folder, a folder''s background, a drive or a library shows Command Prompt (Administrator) and Windows PowerShell (Run as Administrator), opened in that folder.'
    Registry    = @(
        foreach ($p in 'Directory\background\shell', 'Directory\shell', 'Drive\shell', 'LibraryFolder\Shell') {
            & $verb "$c\$p\OpenElevatedCmd" 'Command Prompt (Administrator)' 'cmd.exe' $cmd
            & $verb "$c\$p\OpenElevatedPS" 'Windows PowerShell (Run as Administrator)' 'PowerShell.exe' $ps
        }
    )
}
