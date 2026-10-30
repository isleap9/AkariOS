# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Extract All for Archive Files": the two
# handlers blocked, for 64- and 32-bit programs. Revert deletes the blocks (Windows blocks nothing there).
$b = 'Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'
@{
    Id          = 'context-remove-extract-all'
    Name        = 'Remove Extract All from archives'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'Right-clicking a .zip (or another archive Windows opens) no longer shows Extract All.'
    Registry    = @(
        foreach ($p in "HKLM:\SOFTWARE\$b", "HKLM:\SOFTWARE\WOW6432Node\$b") {
            foreach ($g in '{b8cdcb65-b1bf-4b42-9428-1dfdb7ee92af}', '{EE07CEF5-3441-4CFB-870A-4002C724783A}') {
                @{ Path = $p; Name = $g; Type = 'String'; Value = ''; Default = $null }
            }
        }
    )
}
