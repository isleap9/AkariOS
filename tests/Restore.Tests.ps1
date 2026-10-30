$Core = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Core'

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

Describe 'Get-AkariRestorePoint' {
    foreach ($f in 'Log', 'Registry', 'Restore') { . "$Core\$f.ps1" }
    It 'finds the newest restore point Akari made, by its description' {
        Mock Get-ComputerRestorePoint {
            [pscustomobject]@{ Description = 'Windows Update'; SequenceNumber = 9; CreationTime = '20261019120000.000000-000' }
            [pscustomobject]@{ Description = 'Akari'; SequenceNumber = 3; CreationTime = '20261010120000.000000-000' }
            [pscustomobject]@{ Description = 'AkariOS'; SequenceNumber = 7; CreationTime = '20261018120000.000000-000' }
        }
        $p = Get-AkariRestorePoint
        $p.Description | Should Be 'AkariOS'
        $p.Date.Day | Should Be 18
    }
    It 'is $null when Akari made none' {
        Mock Get-ComputerRestorePoint { [pscustomobject]@{ Description = 'Windows Update'; SequenceNumber = 9; CreationTime = '20261019120000.000000-000' } }
        Get-AkariRestorePoint | Should BeNullOrEmpty
    }
}

Describe 'Restore point choice' {
    $Root = Join-Path (Split-Path $PSScriptRoot) 'src'
    foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
    foreach ($f in 'Selection', 'Steps') { . "$Root\UI\$f.ps1" }
    # no System Restore read and no dialog: both stubbed
    $state = @{ Point = $null; Answer = $false; Asked = 0 }
    function Get-AkariRestorePoint { $state.Point }
    function Confirm-AkariAnotherRestore($p) { $state.Asked++; $state.Answer }
    function Reset([object]$point, [bool]$answer) { $script:RestoreDone = $false; $state.Point = $point; $state.Answer = $answer; $state.Asked = 0 }

    It 'never makes one for Downloads' {
        Reset $null $true
        Get-AkariRestoreChoice 'Downloads' | Should Be $false
    }
    It 'makes one for Install AkariOS and Optimize when Akari has none yet' {
        Reset $null $true
        Get-AkariRestoreChoice 'Guided' | Should Be $true
        Get-AkariRestoreChoice 'Optimize' | Should Be $true
        $state.Asked | Should Be 0
    }
    It 'makes one for Remove apps (the Catalogue''s debloat flow)' {
        Reset $null $true
        Get-AkariRestoreChoice 'Remove apps' | Should Be $true
    }
    It 'asks when an AkariOS restore point exists: No skips it, and is not asked again this session' {
        Reset ([pscustomobject]@{ Description = 'AkariOS'; Date = (Get-Date) }) $false
        Get-AkariRestoreChoice 'Guided' | Should Be $false
        Get-AkariRestoreChoice 'Optimize' | Should Be $false
        $state.Asked | Should Be 1
    }
    It 'asks when an AkariOS restore point exists: Yes makes another one' {
        Reset ([pscustomobject]@{ Description = 'AkariOS'; Date = (Get-Date) }) $true
        Get-AkariRestoreChoice 'OneClick' | Should Be $true
    }
    It 'makes none once this session has one' {
        Reset $null $true
        $script:RestoreDone = $true
        Get-AkariRestoreChoice 'Guided' | Should Be $false
    }

    # Manual mode's prefix (UI\Rows.ps1 wires its buttons at load, so only the function is taken out of the file)
    $ast = [Management.Automation.Language.Parser]::ParseFile("$Root\UI\Rows.ps1", [ref]$null, [ref]$null)
    $fn = $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Add-AkariRestoreFirst' }, $true) | Select-Object -First 1
    . ([scriptblock]::Create($fn.Extent.Text))

    It 'Optimize: the first change of the session runs after a restore point; Check and Open buttons never get one' {
        Reset $null $true
        Add-AkariRestoreFirst 'x' 'Open' | Should Be 'x'
        Add-AkariRestoreFirst 'x' 'Check' | Should Be 'x'
        Add-AkariRestoreFirst 'x' '' | Should Match "^\`$rp = New-AkariRestorePoint 'AkariOS'.*\nx$"
        Add-AkariRestoreFirst 'y' '' | Should Be 'y'
    }
}
