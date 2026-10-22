$Root = Split-Path $PSScriptRoot

# OneClick\ holds only the files One-click's tweaks read; the old imported phase scripts are gone (M4, 2026-10-22)
Describe 'OneClick files' {
    $dir = "$Root\OneClick"

    It 'ships the files the tweaks read' {
        foreach ($f in 'reg.reg', 'settimerresolutionservice.cs', 'start2.txt', 'img.jpg') {
            "$f $(Test-Path "$dir\$f")" | Should Be "$f True"
        }
    }

    It 'has no scripts left (One-click runs Presets\AkariOS.json)' {
        @(Get-ChildItem $dir -Filter *.ps1).Count | Should Be 0
    }
}
