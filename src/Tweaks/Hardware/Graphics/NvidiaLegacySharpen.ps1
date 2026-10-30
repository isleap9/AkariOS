# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\NvidiaAutoinstall.ps1 "Enable Legacy Sharpen": EnableGR535
# = 0 in the driver's FTS key (under Parameters on newer drivers, which have it; else nvlddmkm\FTS), so blocks instead
# of Registry rows. Revert deletes it from both.
@{
    Id          = 'nvidia-legacy-sharpen'
    Name        = 'NVIDIA: legacy image sharpening'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Safe'
    Requires    = 'NVIDIA'
    Guided      = $false
    Reboot      = $true
    Description = 'Brings back the old Image Sharpening setting (sharpen and film grain sliders) in the NVIDIA Control Panel, instead of the newer NIS scaling option.'
    Detect      = {
        $p = if (Get-AkariRegKey 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS') { 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS' } else { 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS' }
        Get-AkariRegistryState @(@{ Path = $p; Name = 'EnableGR535'; Type = 'DWord'; Value = 0; Default = $null })
    }
    Apply       = {
        $p = if (Get-AkariRegKey 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS') { 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS' } else { 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS' }
        Set-Reg $p 'EnableGR535' 0 'DWord'
    }
    Revert      = {
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS' 'EnableGR535'
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS' 'EnableGR535'
    }
}
