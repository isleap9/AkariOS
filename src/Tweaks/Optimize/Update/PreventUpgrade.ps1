# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Prevent OS Upgrade": the target
# release policy (Pro and up), held at the Windows and version this PC runs, read when applied, so blocks instead of
# Registry rows. Revert deletes the policies.
@{
    Id          = 'update-prevent-os-upgrade'
    Name        = 'Stay on this Windows version (group policy)'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Caution'
    Requires    = 'Pro'
    Guided      = $false
    Description = 'Windows Update keeps this PC on the Windows version it runs now (say 24H2): no upgrade to the next version or from Windows 10 to 11. Monthly updates still come, until the version''s support ends.'
    Detect      = {
        $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        $on = Get-AkariRegValue $k 'TargetReleaseVersion'; $info = Get-AkariRegValue $k 'TargetReleaseVersionInfo'; $pv = Get-AkariRegValue $k 'ProductVersion'
        if ($on -eq 1 -and $info -and $pv) { 'Optimized' } elseif ($null -eq $on -and $null -eq $info -and $null -eq $pv) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        # this PC's own version, never the test hive's
        $version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
        if (-not $version) { throw 'this Windows does not say its version' }
        Set-Reg $k 'ProductVersion' $(if ((Get-AkariOSBuild) -ge 22000) { 'Windows 11' } else { 'Windows 10' }) 'String'
        Set-Reg $k 'TargetReleaseVersion' 1 'DWord'
        Set-Reg $k 'TargetReleaseVersionInfo' $version 'String'
    }
    Revert      = {
        $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        foreach ($n in 'ProductVersion', 'TargetReleaseVersion', 'TargetReleaseVersionInfo') { Remove-Reg $k $n }
    }
}
