# From One-click's akarios.ps1 (isleap9/Akari-OS): gets Display Driver Uninstaller ready for the Safe Mode phase
# (oneclick-ddu-clean).
# Action: it only downloads and sets up a tool. Needs 7-Zip (install-7-zip runs before it).
@{
    Id          = 'oneclick-ddu-prepare'
    Name        = 'Get Display Driver Uninstaller ready'
    Section     = 'OneClick'
    Category    = 'Prepare'
    Kind        = 'Action'
    Risk        = 'Safe'
    Description = 'Downloads DDU (AkariOS-Files release), unpacks it to Windows\Temp\ddu and sets its config (no updates, no restore point, no Windows Update driver downloads).'
    Apply       = {
        $dir = "$env:SystemRoot\Temp\ddu"
        $exe = Save-AkariFile 'ddu.exe' "$env:SystemRoot\Temp\ddu.exe"
        $7z = "$env:ProgramFiles\7-Zip\7z.exe"
        if (-not (Test-Path -LiteralPath $7z)) { throw '7-Zip is not installed (install-7-zip)' }
        if ((Invoke-AkariExe $7z @('x', $exe, "-o$dir", '-y')) -ne 0) { throw 'DDU could not be unpacked' }
        $cfg = "$dir\Settings\Settings.xml"
        New-Item (Split-Path $cfg) -ItemType Directory -Force | Out-Null
        if (Test-Path -LiteralPath $cfg) { Set-ItemProperty -LiteralPath $cfg -Name IsReadOnly -Value $false }
        Copy-Item -LiteralPath "$AkariTweakDir\Files\ddu-settings.xml" -Destination $cfg -Force
        # read only, so DDU keeps these settings
        Set-ItemProperty -LiteralPath $cfg -Name IsReadOnly -Value $true
    }
}
