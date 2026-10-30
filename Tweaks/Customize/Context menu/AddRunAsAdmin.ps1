# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\runAsAdmin.reg "Run as Admin for
# ps1,bat,vbs files": a runas verb on .ps1, .msi and .vbs files (.bat already has one; the .reg adds .msi instead).
# Windows has none of these keys, so Revert deletes them.
$c = 'HKLM:\SOFTWARE\Classes'
$verb = { param($k, $command)
    @{ Path = $k; Name = 'HasLUAShield'; Type = 'String'; Value = ''; Default = $null }
    @{ Path = "$k\command"; Name = '(default)'; Type = 'ExpandString'; Value = $command; Default = $null }
    @{ Path = $k; Value = 'Key'; Default = $null }
}
@{
    Id          = 'context-add-run-as-admin'
    Name        = 'Add Run as administrator to .ps1, .msi and .vbs files'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking a PowerShell script, an installer package or a VBScript shows Run as administrator.'
    Registry    = @(
        & $verb "$c\Microsoft.PowerShellScript.1\Shell\runas" 'powershell.exe "-Command" "if((Get-ExecutionPolicy ) -ne ''AllSigned'') { Set-ExecutionPolicy -Scope Process Bypass }; & ''%1''"'
        & $verb "$c\Msi.Package\shell\runas" '"%SystemRoot%\System32\msiexec.exe" /i "%1" %*'
        & $verb "$c\VBSFile\Shell\runas" '"%SystemRoot%\System32\WScript.exe" "%1" %*'
    )
}
