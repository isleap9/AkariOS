# Ported from AkariOS-Ultimate (FR33THY Ultimate) 7 Hardware "Controller Overclock" (hidusbf, a USB polling-rate
# filter driver). Not winget: hidusbf has no package; it comes from the AkariOS-Files release.
# Action: a driver install; hidusbf's own Setup removes it.
@{
    Id          = 'tools-controller-overclock'
    Name        = 'Controller overclock (hidusbf)'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Advanced'
    Description = 'Installs hidusbf, a filter driver that raises a USB controller''s or mouse''s polling rate, and opens its Setup to pick the device and rate (Start menu: hidusbf Setup). Check the result with the controller polling test.'
    Apply       = {
        $root = "${env:ProgramFiles(x86)}\hidusbf"
        Expand-Archive -LiteralPath (Save-AkariFile 'hidusbf.zip' "$env:SystemRoot\Temp\hidusbf.zip") -DestinationPath $root -Force
        # the zip holds one versioned folder ("hidusbf (BB11.5.25)"): its contents go up into hidusbf
        foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -Filter 'hidusbf*' -ErrorAction SilentlyContinue)) {
            Get-ChildItem -LiteralPath $d.FullName | Move-Item -Destination $root -Force
            Remove-Item -LiteralPath $d.FullName -Recurse -Force
        }
        $setup = "$root\DRIVER\Setup.exe"
        [void](Invoke-AkariExe 'rundll32.exe' @("setupapi.dll,InstallHinfSection DefaultInstall 132 $root\DRIVER\HIDUSBF_AS.INF"))
        New-AkariShortcut 'hidusbf Setup' $setup
        Start-Process -FilePath $setup
    }
}
