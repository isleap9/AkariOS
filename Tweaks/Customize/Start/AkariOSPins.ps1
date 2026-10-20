# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar. Windows 11 keeps the pins in
# start2.bin: Files\start2.txt = AkariOS's (Settings and File Explorer, captured on Windows 11 26H2 build 26300,
# 2026-10-20), base64 in certutil's format, the same as OneClick\start2.txt and the copy in the legacy
# Tweaks\Windows.ps1 (a test keeps the three equal); decoded here instead of with certutil. Windows 10 loads a layout
# file once (Files\StartLayout*-Win10.xml; AkariOS's is empty). Revert = Windows' own pins.
@{
    Id          = 'start-akarios-pins'
    Name        = 'AkariOS Start pins'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Caution'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Replaces the Start pins with just Settings and File Explorer (Windows 10: no tiles), for a clean menu to pin your own apps to. Unchecking it brings back the pins Windows starts with (not your own).'
    # Windows 11: ours = Optimized; anything else is someone's pins. Windows 10 can't be read back.
    Detect      = {
        if ((Get-AkariOSBuild) -lt 22000) { return 'Unknown' }
        $bin = "$(Get-AkariUserFolder 'Local AppData')\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
        if (-not (Test-Path -LiteralPath $bin)) { return 'Default' }
        $ours = [Convert]::FromBase64String(((Get-Content "$AkariTweakDir\Files\start2.txt" -Raw) -replace '-----[^-]+-----', '' -replace '\s', ''))
        if (([Convert]::ToBase64String([IO.File]::ReadAllBytes($bin))) -eq [Convert]::ToBase64String($ours)) { 'Optimized' } else { 'Custom' }
    }
    Apply       = {
        if ((Get-AkariOSBuild) -ge 22000) {
            $dir = "$(Get-AkariUserFolder 'Local AppData')\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
            New-Item $dir -ItemType Directory -Force | Out-Null
            $b64 = (Get-Content "$AkariTweakDir\Files\start2.txt" -Raw) -replace '-----[^-]+-----', '' -replace '\s', ''
            [IO.File]::WriteAllBytes("$dir\start2.bin", [Convert]::FromBase64String($b64))
            # Start reads it when it starts; Windows starts it again by itself
            Stop-Process -Name 'StartMenuExperienceHost' -Force -ErrorAction SilentlyContinue
            return
        }
        # Windows 10: lock the layout file, let Explorer load it, then unlock it so the user can pin again
        $xml = "$env:SystemRoot\StartMenuLayout.xml"
        Copy-Item "$AkariTweakDir\Files\StartLayoutEmpty-Win10.xml" $xml -Force
        foreach ($k in 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer') {
            Set-Reg $k 'LockedStartLayout' 1
            Set-Reg $k 'StartLayoutFile' $xml 'ExpandString'
        }
        Restart-AkariExplorer
        Start-Sleep -Seconds 5
        foreach ($k in 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer') {
            Set-Reg $k 'LockedStartLayout' 0
            Remove-Reg $k 'StartLayoutFile'
        }
        Remove-Item $xml -Force -ErrorAction SilentlyContinue
    }
    Revert      = {
        if ((Get-AkariOSBuild) -ge 22000) {
            # no start2.bin: Start builds Windows' default pins again
            Remove-Item "$(Get-AkariUserFolder 'Local AppData')\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -Force -ErrorAction SilentlyContinue
            Stop-Process -Name 'StartMenuExperienceHost' -Force -ErrorAction SilentlyContinue
            return
        }
        $xml = "$env:SystemRoot\StartMenuLayout.xml"
        Copy-Item "$AkariTweakDir\Files\StartLayoutDefault-Win10.xml" $xml -Force
        foreach ($k in 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer') {
            Set-Reg $k 'LockedStartLayout' 1
            Set-Reg $k 'StartLayoutFile' $xml 'ExpandString'
        }
        Restart-AkariExplorer
        Start-Sleep -Seconds 5
        foreach ($k in 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer') {
            Set-Reg $k 'LockedStartLayout' 0
            Remove-Reg $k 'StartLayoutFile'
        }
        Remove-Item $xml -Force -ErrorAction SilentlyContinue
    }
}
