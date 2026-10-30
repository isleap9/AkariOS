# From AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings and One-click's steptwo.ps1
# (isleap9/Akari-OS): "disable set priority notifications" (Do not disturb's priority list: no apps allowed). The
# value is a blob per account in the CloudStore (Files\priority-notifications.txt).
# Action: the blob holds the account's own list, so there is no single Default.
@{
    Id          = 'notifications-priority-list-empty'
    Name        = 'Empty the priority notifications list'
    Section     = 'Customize'
    Category    = 'Notifications'
    Kind        = 'Action'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Do not disturb lets no app''s notifications through (Settings > Notifications > Set priority notifications).'
    Apply       = {
        $cur = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current'
        $guids = @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath $cur) -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^\{[a-f0-9-]+\}\$' } | ForEach-Object { ($_.PSChildName -split '\$')[0] } | Select-Object -Unique)
        if (-not $guids.Count) { 'No account settings yet: nothing to change'; return }
        $data = (Get-Content -LiteralPath "$AkariTweakDir\Files\priority-notifications.txt" | Where-Object { -not $_.StartsWith(';') }) -join "`r`n"
        $text = "Windows Registry Editor Version 5.00`r`n"
        foreach ($g in $guids) {
            $text += "`r`n[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\$g`$windows.data.donotdisturb.quiethoursprofile`$quiethoursprofilelist\windows.data.donotdisturb.quiethoursprofile`$microsoft.quiethoursprofile.priorityonly]`r`n$data`r`n"
        }
        if ((Import-AkariRegText $text) -ne 0) { throw 'reg.exe could not import the priority list' }
    }
}
