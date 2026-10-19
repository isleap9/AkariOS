# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
@{
    Id          = 'msi-afterburner'
    Name        = 'MSI Afterburner'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Gaming & hardware'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Description = 'GPU monitoring and overclocking, with RivaTuner and the AkariOS overlay. GPU power logging is off: it causes FPS and 1% low drops.'
    Winget      = 'Guru3D.Afterburner', 'Guru3D.RTSS'
    After       = {
        # Akari's settings and overlay (Files\Afterburner mirrors Program Files (x86)): MSI Afterburner\Profiles,
        # RivaTuner Statistics Server\Profiles, \Plugins\Client (overlay editor, hotkeys, akarios.ovl) and DesktopOverlayHost.cfg
        Copy-Item "$AkariTweakDir\Files\Afterburner\*" "${env:ProgramFiles(x86)}" -Recurse -Force
    }
}
