# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced "ReBar Force": its Force On (a merge import of
# rBAR - Enable = 1 into the driver's Base Profile, with NVIDIA Profile Inspector). Not ported: Force Off (rare) and
# To Bios (tools-restart-to-bios). The driver profile can't be read back: Detect reads what Akari last did (state.json;
# never done = the driver's default), and Apply / Revert write it.
# Revert imports the whole Base Profile again without the rBAR line: FR33THY's when graphics-nvidia-settings is
# applied (its registry part, as its Detect reads it), else the empty one, so the driver's per-game list decides.
@{
    Id          = 'graphics-nvidia-rebar-force'
    Name        = 'Force Resizable BAR on (NVIDIA)'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Advanced'
    Requires    = 'NVIDIA'
    Guided      = $false
    Description = 'Resizable BAR for every game, not just the ones NVIDIA''s driver lists. Turn it on in the BIOS first (Tools > Check: BIOS check; GPU-Z shows it). Some games run worse with it.'
    Detect      = { if (Get-AkariRememberedState 'graphics-nvidia-rebar-force') { 'Optimized' } else { 'Default' } }
    Apply       = {
        Get-ChildItem "$env:ProgramData\NVIDIA Corporation\Drs" -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
        $exe = "${env:ProgramFiles(x86)}\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
        if (-not (Test-Path -LiteralPath $exe)) { [void](Save-AkariFile 'inspector.exe' $exe) }
        New-AkariShortcut 'Nvidia Profile Inspector' $exe
        Start-Process -FilePath $exe -ArgumentList "-silentImport -mergeImport -silent `"$AkariTweakDir\Files\nvidia-rebar-on.nip`"" -Wait
        Set-AkariRememberedState 'graphics-nvidia-rebar-force' $true
    }
    Revert      = {
        Get-ChildItem "$env:ProgramData\NVIDIA Corporation\Drs" -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
        $exe = "${env:ProgramFiles(x86)}\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
        if (-not (Test-Path -LiteralPath $exe)) { [void](Save-AkariFile 'inspector.exe' $exe) }
        $nv = 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\Global\NVTweak'
        $fr33thy = (Get-AkariRegValue $nv 'NvCplPhysxAuto') -eq 0 -and (Get-AkariRegValue $nv 'NvDevToolsVisible') -eq 1
        $nip = if ($fr33thy) { 'nvidia-base-profile.nip' } else { 'nvidia-default-profile.nip' }
        Start-Process -FilePath $exe -ArgumentList "-silentImport -silent `"$AkariTweakDir\Files\$nip`"" -Wait
        Set-AkariRememberedState 'graphics-nvidia-rebar-force' $false
    }
}
