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

# writes HKLM registry rows (Registry.ps1's @{ Path; Name; Type; Value; Default }) as TrustedInstaller, for keys an
# admin can't change (Defender's). $Mode Apply = Value, Revert = Default ($null = delete). A few rows per Run-Trusted
# call: its command goes through a service command line, which has a length limit. HKCU rows are skipped (they belong to
# the real user: Set-Reg them).
function Invoke-AkariRegistryTrusted([hashtable[]]$Entries, [ValidateSet('Apply', 'Revert')][string]$Mode) {
    $batch = ''
    foreach ($e in @($Entries | Where-Object { $_.Path -like 'HKLM:\*' })) {
        $k = 'Registry::HKEY_LOCAL_MACHINE\' + $e.Path.Substring(6)
        $v = if ($Mode -eq 'Apply') { $e.Value } else { Resolve-AkariDefault $e.Default }
        $cmd = if ($null -eq $v) { "Remove-ItemProperty -LiteralPath '$k' -Name '$($e.Name)' -ErrorAction SilentlyContinue" } else {
            $lit = if ($e.Type -eq 'Binary') { '([byte[]](' + (@($v | ForEach-Object { [int]$_ }) -join ',') + '))' } elseif ($e.Type -in 'String', 'ExpandString') { "'$($v -replace "'", "''")'" } else { "$v" }
            "if (-not (Test-Path -LiteralPath '$k')) { New-Item -Path '$k' -Force | Out-Null }; New-ItemProperty -LiteralPath '$k' -Name '$($e.Name)' -Value $lit -PropertyType $($e.Type) -Force | Out-Null"
        }
        if ($batch -and ($batch.Length + $cmd.Length) -gt 1200) { Run-Trusted $batch; $batch = '' }
        $batch = if ($batch) { "$batch; $cmd" } else { $cmd }
    }
    if ($batch) { Run-Trusted $batch }
}
