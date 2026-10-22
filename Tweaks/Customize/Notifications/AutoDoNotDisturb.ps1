# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings: "disable focus assist", "disable
# turn on do not disturb automatically" and "disable focus settings". The values are CloudStore blobs
# (Files\do-not-disturb.psd1); FR33THY's key names had "?" where Windows has "$", so this is the first version that
# reaches them: the automatic rules are written for the "default" prefix and for each account's {guid}.
@{
    Id          = 'notifications-no-auto-dnd'
    Name        = 'Do not disturb never turns on by itself'
    Section     = 'Customize'
    Category    = 'Notifications'
    Risk        = 'Safe'
    Description = 'Do not disturb no longer turns on during games, full screen apps, presentations or after an update, and focus sessions keep the default theme.'
    Detect      = {
        $d = Import-PowerShellDataFile "$AkariTweakDir\Files\do-not-disturb.psd1"
        $s = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store'
        $acc = @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath "$s\DefaultAccount\Current") -ErrorAction SilentlyContinue |
            ForEach-Object { if ($_.PSChildName -match '^(\{[0-9a-fA-F-]+\})\$windows\.data\.donotdisturb\.quietmoment\$quietmomentlist$') { $Matches[1] } })
        $rows = @(foreach ($p in @('default') + $acc) { foreach ($r in $d.Rules) {
            @{ Path = "$s\DefaultAccount\Current\$p`$$($r.Key)"; Name = 'Data'; Type = 'Binary'; Value = (ConvertFrom-AkariHex $r.Off); Default = (ConvertFrom-AkariHex $r.Default) } } })
        $rows += @{ Path = "$s\$($d.Focus.Key)"; Name = 'Data'; Type = 'Binary'; Value = (ConvertFrom-AkariHex $d.Focus.Off); Default = $null }
        Get-AkariRegistryState $rows
    }
    Apply       = {
        $d = Import-PowerShellDataFile "$AkariTweakDir\Files\do-not-disturb.psd1"
        $s = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store'
        $acc = @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath "$s\DefaultAccount\Current") -ErrorAction SilentlyContinue |
            ForEach-Object { if ($_.PSChildName -match '^(\{[0-9a-fA-F-]+\})\$windows\.data\.donotdisturb\.quietmoment\$quietmomentlist$') { $Matches[1] } })
        foreach ($p in @('default') + $acc) { foreach ($r in $d.Rules) { Set-Reg "$s\DefaultAccount\Current\$p`$$($r.Key)" 'Data' (ConvertFrom-AkariHex $r.Off) 'Binary' } }
        foreach ($r in $d.Cache) { Set-Reg "$s\$($r.Key)" 'Data' (ConvertFrom-AkariHex $r.Off) 'Binary' }
        Set-Reg "$s\$($d.Focus.Key)" 'Data' (ConvertFrom-AkariHex $d.Focus.Off) 'Binary'
    }
    Revert      = {
        $d = Import-PowerShellDataFile "$AkariTweakDir\Files\do-not-disturb.psd1"
        $s = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store'
        $acc = @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath "$s\DefaultAccount\Current") -ErrorAction SilentlyContinue |
            ForEach-Object { if ($_.PSChildName -match '^(\{[0-9a-fA-F-]+\})\$windows\.data\.donotdisturb\.quietmoment\$quietmomentlist$') { $Matches[1] } })
        foreach ($p in @('default') + $acc) { foreach ($r in $d.Rules) { Set-Reg "$s\DefaultAccount\Current\$p`$$($r.Key)" 'Data' (ConvertFrom-AkariHex $r.Default) 'Binary' } }
        foreach ($r in $d.Cache) { Set-Reg "$s\$($r.Key)" 'Data' (ConvertFrom-AkariHex $r.Default) 'Binary' }
        # FR33THY's Default deletes the focus theme key
        $f = Resolve-AkariRegPath "$s\$($d.Focus.Key)"
        if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Recurse -Force }
    }
}
