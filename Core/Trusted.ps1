# Runs a command as TrustedInstaller (one copy only: tweaks call this instead of inlining their own).
function Run-Trusted([String]$command) {
    try { Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop }
    catch { taskkill /im trustedinstaller.exe /f >$null }
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='TrustedInstaller'"
    $DefaultBinPath = $service.PathName
    $trustedInstallerPath = "$env:SystemRoot\servicing\TrustedInstaller.exe"
    if ($DefaultBinPath -ne $trustedInstallerPath) { $DefaultBinPath = $trustedInstallerPath }
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $base64Command = [Convert]::ToBase64String($bytes)
    sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" | Out-Null
    sc.exe start TrustedInstaller | Out-Null
    sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" | Out-Null
    try { Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop }
    catch { taskkill /im trustedinstaller.exe /f >$null }
}
