# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Take Ownership": a runas verb on files
# and folders that takes ownership and gives the administrators group full control. Windows has neither key (files
# and folders have no runas verb), so Revert deletes them.
$c = 'HKLM:\SOFTWARE\Classes'
$file = 'cmd.exe /c takeown /f "%1" && icacls "%1" /grant *S-1-5-32-544:F'
$folder = 'cmd.exe /c takeown /f "%1" /r /d y && icacls "%1" /grant *S-1-5-32-544:F /t'
$verb = { param($k, $command)
    @{ Path = $k; Name = '(default)'; Type = 'String'; Value = 'Take Ownership'; Default = $null }
    @{ Path = "$k\command"; Name = '(default)'; Type = 'String'; Value = $command; Default = $null }
    @{ Path = "$k\command"; Name = 'IsolatedCommand'; Type = 'String'; Value = $command; Default = $null }
    @{ Path = $k; Value = 'Key'; Default = $null }
}
@{
    Id          = 'context-add-take-ownership'
    Name        = 'Add Take Ownership to files and folders'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Right-clicking a file or folder shows Take Ownership, which makes the administrators group its owner with full control (a folder: everything in it too). Used on Windows'' own files, it can break updates.'
    Registry    = @(
        & $verb "$c\*\shell\runas" $file
        & $verb "$c\Directory\shell\runas" $folder
    )
}
