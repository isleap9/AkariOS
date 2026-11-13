# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), Invoke-WinUtilSSHServer.ps1:
# the capability, sshd and ssh-agent started with Windows, administrators_authorized_keys for Administrators and SYSTEM
# only. No firewall rule: the capability makes its own (OpenSSH-Server-In-TCP). Revert removes the capability and puts
# ssh-agent back off (Windows' own); the keys file stays (the user's data).
@{
    Id          = 'features-openssh-server'
    Name        = 'OpenSSH Server'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Lets you sign in to this PC from another one with ssh (port 22). An administrator''s public keys go in ProgramData\ssh\administrators_authorized_keys. Its files come from Windows Update.'
    Detect      = {
        $s = Get-AkariCapabilityState 'OpenSSH.Server~~~~0.0.1.0'
        if ($null -eq $s) { 'Unknown' } elseif ($s -eq 'Installed') { 'Optimized' } else { 'Default' }
    }
    Apply       = {
        . "$AkariTweakDir\Files\Features.ps1"
        $s = Get-AkariCapabilityState 'OpenSSH.Server~~~~0.0.1.0'
        if ($null -eq $s) { throw 'this Windows has no OpenSSH Server' }
        if ($s -ne 'Installed') {
            Write-Log 'Adding OpenSSH Server (it takes a while)'
            Use-WindowsUpdate { Add-AkariCapability 'OpenSSH.Server~~~~0.0.1.0' } 'Connect to the internet and try again'
        }
        foreach ($n in 'sshd', 'ssh-agent') {
            if (-not (Get-AkariServices $n)) { Write-Log "OpenSSH Server: no $n service, skipped"; continue }
            Set-AkariServiceStart $n 'Automatic'
            Invoke-AkariServiceControl $n 'Start'
        }
        $keys = "$env:ProgramData\ssh\administrators_authorized_keys"
        Set-AkariAdminOnlyAcl $keys
        Write-Log "OpenSSH Server: on. Administrators' public keys go in $keys"
    }
    Revert      = {
        if ((Get-AkariCapabilityState 'OpenSSH.Server~~~~0.0.1.0') -eq 'Installed') {
            if (Get-AkariServices 'sshd') { Invoke-AkariServiceControl 'sshd' 'Stop' }
            Write-Log 'Removing OpenSSH Server'
            Remove-AkariCapability 'OpenSSH.Server~~~~0.0.1.0'
        }
        if (Get-AkariServices 'ssh-agent') {
            Invoke-AkariServiceControl 'ssh-agent' 'Stop'
            Set-AkariServiceStart 'ssh-agent' 'Disabled'
        }
    }
}
