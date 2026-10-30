# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics\5 Nvidia Settings. The driver profile is imported with
# NVIDIA Profile Inspector (AkariOS-Files release: not on winget) from Files\nvidia-base-profile.nip; Revert imports
# the empty one (driver defaults). Detect reads the registry part only: the profile can't be read back.
@{
    Id          = 'graphics-nvidia-settings'
    Name        = 'NVIDIA settings'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Caution'
    Requires    = 'NVIDIA'
    Description = 'FR33THY''s NVIDIA profile: low latency on, VSync and G-SYNC off, max performance power, quality filtering off; PhysX on the GPU, no tray icon. Installs NVIDIA Profile Inspector.'
    Detect      = {
        $nv = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\Global\NVTweak'
        $v = @((Get-AkariRegValue $nv 'NvCplPhysxAuto'), (Get-AkariRegValue $nv 'NvDevToolsVisible'), (Get-AkariRegValue 'HKCU:\Software\NVIDIA Corporation\NvTray' 'StartOnLogin'))
        if ($v[0] -eq 0 -and $v[1] -eq 1 -and $v[2] -eq 0) { 'Optimized' } elseif (@($v | Where-Object { $null -ne $_ }).Count -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        Get-ChildItem "$env:ProgramData\NVIDIA Corporation\Drs" -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
        $nv = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\Global\NVTweak'
        Set-Reg $nv 'NvCplPhysxAuto' 0
        Set-Reg $nv 'NvDevToolsVisible' 1
        Set-Reg $nv 'RmProfilingAdminOnly' 0
        Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Set-Reg $_.Path 'RmProfilingAdminOnly' 0 }
        Set-Reg 'HKCU:\Software\NVIDIA Corporation\NvTray' 'StartOnLogin' 0
        # the legacy sharpening filter in the control panel
        foreach ($k in 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS', 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS') { Set-Reg $k 'EnableGR535' 0 }
        $exe = "${env:ProgramFiles(x86)}\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
        if (-not (Test-Path -LiteralPath $exe)) { [void](Save-AkariFile 'inspector.exe' $exe) }
        New-AkariShortcut 'Nvidia Profile Inspector' $exe
        Start-Process -FilePath $exe -ArgumentList "-silentImport -silent `"$AkariTweakDir\Files\nvidia-base-profile.nip`"" -Wait
    }
    Revert      = {
        Get-ChildItem "$env:ProgramData\NVIDIA Corporation\Drs" -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
        $nv = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\Global\NVTweak'
        foreach ($n in 'NvCplPhysxAuto', 'NvDevToolsVisible', 'RmProfilingAdminOnly') { Remove-Reg $nv $n }
        Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Remove-Reg $_.Path 'RmProfilingAdminOnly' }
        Remove-Reg 'HKCU:\Software\NVIDIA Corporation\NvTray' 'StartOnLogin'
        foreach ($k in 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS', 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS') { Set-Reg $k 'EnableGR535' 1 }
        $exe = "${env:ProgramFiles(x86)}\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
        if (-not (Test-Path -LiteralPath $exe)) { [void](Save-AkariFile 'inspector.exe' $exe) }
        Start-Process -FilePath $exe -ArgumentList "-silentImport -silent `"$AkariTweakDir\Files\nvidia-default-profile.nip`"" -Wait
    }
}
