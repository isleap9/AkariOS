# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings. A Choice over IconSizePreference
# (a Value block: the Windows default deletes the value, so no Choice value is $null). Never small is the AkariOS
# pick (OneClick\reg.reg).
# Always small: ZOICWARE's W11Tweaks "Small Taskbar Icons" (https://github.com/zoicware/ZOICWARE, MIT).
@{
    Id          = 'taskbar-never-small-icons'
    Name        = 'Never shrink taskbar icons'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Kind        = 'Choice'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Explorer    = $true
    Description = 'Taskbar icons stay full size even when the taskbar is full (or are always small, ZOICWARE''s pick). Windows shrinks them only when the taskbar is full.'
    Choices     = @(
        @{ Value = 'Never'; Label = 'Never small' }
        @{ Value = 'Always'; Label = 'Always small (ZOICWARE)' }
        @{ Value = 'Default'; Label = 'Small when the taskbar is full' }
    )
    Recommended = 'Never'
    Default     = 'Default'
    Value       = {
        $v = Get-AkariRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconSizePreference'
        if ($null -eq $v) { 'Default' } elseif ($v -eq 1) { 'Never' } elseif ($v -eq 0) { 'Always' } else { $null }
    }
    Apply       = {
        $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        switch ($AkariValue) {
            'Never' { Set-Reg $k 'IconSizePreference' 1 'DWord' }
            'Always' { Set-Reg $k 'IconSizePreference' 0 'DWord' }
            'Default' { Remove-Reg $k 'IconSizePreference' }
            default { throw "unknown value $AkariValue" }
        }
    }
    Revert      = { Remove-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconSizePreference' }
}
