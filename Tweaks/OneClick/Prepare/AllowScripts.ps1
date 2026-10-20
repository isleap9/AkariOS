# From One-click's akarios.ps1 (isleap9/Akari-OS): "allow double click powershell scripts".
# Action: the execution
# policy Windows starts with depends on the edition and on policies, so there is no single Default to go back to.
@{
    Id          = 'oneclick-allow-scripts'
    Name        = 'PowerShell scripts run on double-click'
    Section     = 'OneClick'
    Category    = 'Prepare'
    Kind        = 'Action'
    Risk        = 'Caution'
    Description = 'A .ps1 file opens in PowerShell when double-clicked, and the execution policy is Unrestricted.'
    Apply       = {
        Set-Reg 'HKLM:\SOFTWARE\Classes\Applications\powershell.exe\shell\open\command' '(default)' "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -ExecutionPolicy unrestricted -File `"%1`"" 'String'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' 'ExecutionPolicy' 'Unrestricted' 'String'
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' 'ExecutionPolicy' 'Unrestricted' 'String'
    }
}
