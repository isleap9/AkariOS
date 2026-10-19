$Root = Split-Path $PSScriptRoot

# Static checks only: the real One-click scripts are never run here (AGENTS.md rule 12)
Describe 'OneClick files' {
    $dir = "$Root\OneClick"

    It 'ships every file the run needs' {
        foreach ($f in 'OneClick.ps1', 'akarios.ps1', 'stepone.ps1', 'steptwo.ps1', 'reg.reg', 'settimerresolutionservice.cs', 'start2.txt', 'img.jpg') {
            "$f $(Test-Path "$dir\$f")" | Should Be "$f True"
        }
    }

    It 'scripts have no parse errors' {
        foreach ($f in 'OneClick.ps1', 'akarios.ps1', 'stepone.ps1', 'steptwo.ps1') {
            $errs = $null
            [void][Management.Automation.Language.Parser]::ParseFile("$dir\$f", [ref]$null, [ref]$errs)
            "$f $($errs.Count)" | Should Be "$f 0"
        }
    }

    It 'akarios.ps1 copies its files from next to itself instead of downloading them' {
        Select-String -Path "$dir\akarios.ps1" -SimpleMatch 'Copy-Item "$PSScriptRoot\$f" "$env:SystemRoot\Temp\$f"' -Quiet | Should Be $true
        Select-String -Path "$dir\akarios.ps1" -SimpleMatch 'Copy-Item "$PSScriptRoot\img.jpg"' -Quiet | Should Be $true
        Select-String -Path "$dir\akarios.ps1" -SimpleMatch 'raw/refs/heads/main' -Quiet | Should Be $false
    }

    It 'the phase scripts no longer chain themselves (Akari does: RunOnce, Safe Mode, restart after phase 1)' {
        $code = @(Get-Content "$dir\akarios.ps1" | Where-Object { $_ -notmatch '^\s*#' })
        @($code | Where-Object { $_ -match 'RunOnce|safeboot|shutdown|\bPause\b' }).Count | Should Be 0
        Select-String -Path "$dir\akarios.ps1" -SimpleMatch 'throw "Internet connection required' -Quiet | Should Be $true
    }

    It 'the phase scripts leave elevation and the console to Akari' {
        foreach ($f in 'akarios.ps1', 'stepone.ps1', 'steptwo.ps1') {
            "$f $(Select-String -Path "$dir\$f" -Pattern 'SCRIPT RUN AS ADMIN|Clear-Host' -Quiet)" | Should Be "$f False"
        }
    }
}

# Invoke-AkariOneClick against a fake AkariOS folder; bcdedit, RunOnce, restart and the key wait are mocked
Describe 'Invoke-AkariOneClick' {
    $AkariLogFile = "$TestDrive\akari.log"
    foreach ($f in 'Log', 'Registry', 'Phases') { . "$Root\Core\$f.ps1" }
    . "$Root\OneClick\OneClick.ps1"
    $fake = "$TestDrive\Akari"
    New-Item "$fake\OneClick" -ItemType Directory -Force | Out-Null
    Mock Write-Host { }
    Mock Set-AkariSafeBoot { }
    Mock Register-AkariResume { }
    Mock Remove-Reg { }
    Mock Restart-AkariPC { }
    Mock Wait-AkariKey { }

    It 'phase 1: runs akarios.ps1, Safe Mode on, registers phases 2 and 3, restarts' {
        Set-Content "$fake\OneClick\akarios.ps1" "Set-Content '$TestDrive\ran.txt' 'phase1'"
        Invoke-AkariOneClick 1 $fake | Should Be $true
        Get-Content "$TestDrive\ran.txt" | Should Be 'phase1'
        Assert-MockCalled Set-AkariSafeBoot -Times 1 -Exactly -Scope It -ParameterFilter { $On -eq $true }
        Assert-MockCalled Register-AkariResume -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq '*!akari-oneclick-2' -and $Command -like "*`"$fake\Akari.ps1`" -OneClick 2" }
        Assert-MockCalled Register-AkariResume -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq '!akari-oneclick-3' -and $Command -like "*`"$fake\Akari.ps1`" -OneClick 3" }
        Assert-MockCalled Restart-AkariPC -Times 1 -Exactly -Scope It
    }

    It 'phase 1 that throws: nothing registered, no Safe Mode, no restart' {
        Set-Content "$fake\OneClick\akarios.ps1" "throw 'Internet connection required. Nothing was changed.'"
        Invoke-AkariOneClick 1 $fake | Should Be $false
        Assert-MockCalled Set-AkariSafeBoot -Times 0 -Exactly -Scope It
        Assert-MockCalled Register-AkariResume -Times 0 -Exactly -Scope It
        Assert-MockCalled Restart-AkariPC -Times 0 -Exactly -Scope It
        Assert-MockCalled Wait-AkariKey -Times 1 -Exactly -Scope It
        Get-Content $AkariLogFile -Raw | Should Match 'Internet connection required'
    }

    It 'Safe Mode that fails after phase 1: RunOnce and Safe Mode are undone, no restart' {
        Set-Content "$fake\OneClick\akarios.ps1" "'ok' | Out-Null"
        Mock Set-AkariSafeBoot { if ($On) { throw 'bcdedit could not turn Safe Mode on' } }
        Invoke-AkariOneClick 1 $fake | Should Be $false
        Assert-MockCalled Remove-Reg -Times 2 -Exactly -Scope It
        Assert-MockCalled Set-AkariSafeBoot -Times 1 -Exactly -Scope It -ParameterFilter { $On -eq $false }
        Assert-MockCalled Restart-AkariPC -Times 0 -Exactly -Scope It
    }

    It 'phases 2 and 3: run their script only (they restart by themselves)' {
        Mock Set-AkariSafeBoot { }
        Set-Content "$fake\OneClick\stepone.ps1" "Set-Content '$TestDrive\ran.txt' 'phase2'"
        Set-Content "$fake\OneClick\steptwo.ps1" "Set-Content '$TestDrive\ran.txt' 'phase3'"
        Invoke-AkariOneClick 2 $fake | Should Be $true
        Get-Content "$TestDrive\ran.txt" | Should Be 'phase2'
        Invoke-AkariOneClick 3 $fake | Should Be $true
        Get-Content "$TestDrive\ran.txt" | Should Be 'phase3'
        Assert-MockCalled Register-AkariResume -Times 0 -Exactly -Scope It
        Assert-MockCalled Restart-AkariPC -Times 0 -Exactly -Scope It
    }
}
