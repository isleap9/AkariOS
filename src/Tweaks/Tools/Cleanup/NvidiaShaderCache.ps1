# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Clean Nvidia Driver Shader Cache"
# (Ultimate Cleanup): the OpenGL and DirectX caches, the real user's.
# Action: games rebuild them, nothing to put back.
@{
    Id          = 'cleanup-nvidia-shader-cache'
    Name        = 'Delete the NVIDIA shader cache'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Safe'
    Requires    = 'NVIDIA'
    Guided      = $false
    Description = 'Deletes the NVIDIA driver''s OpenGL and DirectX shader caches. Games build them again (expect some stutter the first time); worth it after a driver update or when a game stutters.'
    Confirm     = 'Delete the NVIDIA shader cache? Games will rebuild it, with some stutter at first.'
    Apply       = {
        $local = Get-AkariUserFolder 'Local AppData'
        $low = Join-Path (Split-Path $local) 'LocalLow'
        $n = Remove-AkariPaths @("$local\NVIDIA\GLCache", "$low\NVIDIA\PerDriverVersion\DXCache")
        "Deleted $n shader caches"
    }
}
