$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'

# Mocks only: nothing here creates a real restore point or touches HKLM
Describe 'New-AkariRestorePoint' {
    foreach ($f in 'Log', 'Registry', 'Restore') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    Mock Enable-ComputerRestore { }
    Mock Get-AkariRegValue { $null }
    Mock Set-Reg { }
    Mock Remove-Reg { }

    It 'is Ok when the first checkpoint works' {
        Mock Checkpoint-Computer { }
        (New-AkariRestorePoint).Ok | Should Be $true
        Assert-MockCalled Enable-ComputerRestore -Times 0 -Exactly -Scope It
    }

    It 'enables protection and retries once' {
        $script:calls = 0
        Mock Checkpoint-Computer { $script:calls++; if ($script:calls -eq 1) { throw 'protection is off' } }
        (New-AkariRestorePoint).Ok | Should Be $true
        $script:calls | Should Be 2
        Assert-MockCalled Enable-ComputerRestore -Times 1 -Exactly -Scope It
    }

    It 'treats the 24 hour warning as a failure and retries' {
        $script:calls = 0
        Mock Checkpoint-Computer { $script:calls++; if ($script:calls -eq 1) { Write-Warning 'A new system restore point cannot be created because one has already been created within the past 1440 minutes.' } }
        (New-AkariRestorePoint).Ok | Should Be $true
        $script:calls | Should Be 2
    }

    It 'puts the throttle value back (removes it when it was absent)' {
        $script:calls = 0
        Mock Checkpoint-Computer { $script:calls++; if ($script:calls -eq 1) { throw 'x' } }
        [void](New-AkariRestorePoint)
        Assert-MockCalled Set-Reg -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq 'SystemRestorePointCreationFrequency' -and $Value -eq 0 }
        Assert-MockCalled Remove-Reg -Times 1 -Exactly -Scope It -ParameterFilter { $Name -eq 'SystemRestorePointCreationFrequency' }
    }

    It 'puts an existing throttle value back' {
        Mock Get-AkariRegValue { 1440 }
        Mock Checkpoint-Computer { throw 'x' }
        [void](New-AkariRestorePoint)
        Assert-MockCalled Set-Reg -Times 1 -Exactly -Scope It -ParameterFilter { $Value -eq 1440 }
    }

    It 'reports failure without throwing' {
        Mock Checkpoint-Computer { throw 'service is disabled' }
        $r = New-AkariRestorePoint
        $r.Ok | Should Be $false
        $r.Message | Should Match 'service is disabled'
    }
}
