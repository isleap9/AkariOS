$Root = Split-Path $PSScriptRoot

# Static checks only: the One-click scripts are never run here (AGENTS.md rule 12)
Describe 'OneClick' {
    $dir = "$Root\OneClick"

    It 'ships every file the run needs' {
        foreach ($f in 'akarios.ps1', 'stepone.ps1', 'steptwo.ps1', 'reg.reg', 'settimerresolutionservice.cs', 'start2.txt', 'img.jpg') {
            "$f $(Test-Path "$dir\$f")" | Should Be "$f True"
        }
    }

    It 'scripts have no parse errors' {
        foreach ($f in 'akarios.ps1', 'stepone.ps1', 'steptwo.ps1') {
            $errs = $null
            [void][Management.Automation.Language.Parser]::ParseFile("$dir\$f", [ref]$null, [ref]$errs)
            "$f $($errs.Count)" | Should Be "$f 0"
        }
    }

    It 'akarios.ps1 copies its files from next to itself instead of downloading them' {
        Select-String -Path "$dir\akarios.ps1" -SimpleMatch 'Copy-Item "$PSScriptRoot\$f" "$env:SystemRoot\Temp\$f"' -Quiet | Should Be $true
        Select-String -Path "$dir\akarios.ps1" -SimpleMatch 'Copy-Item "$PSScriptRoot\img.jpg"' -Quiet | Should Be $true
    }
}
