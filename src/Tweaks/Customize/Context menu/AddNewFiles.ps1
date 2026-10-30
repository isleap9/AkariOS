# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\newMenu.reg "Add bat,ps1 and reg to
# New File Menu": a ShellNew key per type. Its newMenu11.reg (a ps1legacy class set as the user's .ps1 type, which
# loses Run with PowerShell and Edit) is not used. Windows has none of these keys, so Revert deletes them.
$c = 'HKLM:\SOFTWARE\Classes'
$new = { param($ext, $name)
    @{ Path = "$c\$ext\ShellNew"; Name = 'ItemName'; Type = 'ExpandString'; Value = $name; Default = $null }
    @{ Path = "$c\$ext\ShellNew"; Name = 'NullFile'; Type = 'String'; Value = ''; Default = $null }
    @{ Path = "$c\$ext\ShellNew"; Value = 'Key'; Default = $null }
}
@{
    Id          = 'context-add-new-files'
    Name        = 'Add batch, PowerShell and registry files to New'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'The New menu (right-click a folder''s background) can make an empty .bat, .ps1 or .reg file.'
    Registry    = @(
        & $new '.bat' '@C:\Windows\System32\acppage.dll,-6002'
        & $new '.ps1' '@"C:\Windows\system32\windowspowershell\v1.0\powershell.exe",-103'
        & $new '.reg' '@C:\Windows\regedit.exe,-309'
    )
}
