# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\ps1Options.reg "Additional ps1
# options": a "Run or modify..." submenu on .ps1 files. Windows has no run_edit key, so Revert deletes it.
$k = 'HKLM:\SOFTWARE\Classes\SystemFileAssociations\.ps1\Shell\run_edit'
$item = { param($n, $verb, $icon, $command, [switch]$Shield, [switch]$Flags)
    @{ Path = "$k\shell\$n"; Name = 'MUIVerb'; Type = 'String'; Value = $verb; Default = $null }
    @{ Path = "$k\shell\$n"; Name = 'Icon'; Type = 'String'; Value = $icon; Default = $null }
    if ($Shield) { @{ Path = "$k\shell\$n"; Name = 'HasLUAShield'; Type = 'String'; Value = ''; Default = $null } }
    if ($Flags) { @{ Path = "$k\shell\$n"; Name = 'CommandFlags'; Type = 'DWord'; Value = 0x20; Default = $null } }
    @{ Path = "$k\shell\$n\Command"; Name = '(default)'; Type = 'String'; Value = $command; Default = $null }
}
$ise = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell_ise.exe'
$isex86 = 'C:\Windows\Syswow64\WindowsPowerShell\v1.0\powershell_ise.exe'
@{
    Id          = 'context-add-ps1-options'
    Name        = 'Add Run or modify to .ps1 files'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking a PowerShell script shows a Run or modify submenu: run it (also as administrator), or open it in PowerShell ISE or Notepad (also as administrator).'
    Registry    = @(
        @{ Path = $k; Name = 'SubCommands'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = 'Run or modify...'; Default = $null }
        & $item '001RunwithPS' 'Run with PowerShell' 'powershell.exe' 'powershell.exe "-Command" "if((Get-ExecutionPolicy ) -ne ''AllSigned'') { Set-ExecutionPolicy -Scope Process Bypass }; & ''%1''"'
        & $item '002RunwithPSElevated' 'Run with PowerShell as administrator' 'powershell.exe' 'powershell.exe "-Command" ""& {Start-Process PowerShell.exe -ArgumentList ''-ExecutionPolicy RemoteSigned -File \"%1\"'' -Verb RunAs}"' -Shield
        & $item '005EditwithISE' 'Open in PowerShell ISE' 'powershell_ise.exe' "$ise `"%1`"" -Flags
        & $item '006EditwithISEelevated' 'Open in PowerShell ISE as administrator' 'powershell_ise.exe' 'PowerShell -windowstyle hidden -Command "Start-Process cmd -ArgumentList ''/s,/c,start PowerShell_ISE.exe ""%1""''  -Verb RunAs"' -Shield
        & $item '007EditwithISEx86' 'Open in PowerShell ISE (x86)' 'powershell_ise.exe' "$isex86 `"%1`"" -Flags
        & $item '008EditwithISEx86elevated' 'Open in PowerShell ISE (x86) as administrator' 'powershell_ise.exe' 'PowerShell -windowstyle hidden -Command "Start-Process cmd -ArgumentList ''/s,/c,start %windir%\syswow64\WindowsPowerShell\v1.0\powershell_ise.exe ""%1""''  -Verb RunAs"' -Shield
        & $item '009EditwithNotepad' 'Open in Notepad' 'notepad.exe' 'C:\Windows\System32\notepad.exe "%1"' -Flags
        & $item '010EditwithNotepadElevated' 'Open in Notepad as administrator' 'notepad.exe' 'PowerShell -windowstyle hidden -Command "Start-Process cmd -ArgumentList ''/s,/c,start notepad.exe ""%1""''  -Verb RunAs"' -Shield
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
