$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'
$Fixtures = Join-Path $PSScriptRoot 'Fixtures\Tweaks'

Describe 'Get-AkariTweaks' {
    . "$Core\Loader.ps1"
    $r = Get-AkariTweaks $Fixtures
    $byId = @{}; foreach ($t in $r.Tweaks) { $byId[$t.Id] = $t }
    function Get-Problem([string]$file) { @($r.Problems | Where-Object { $_.File -like "*\$file" }) }

    It 'loads a registry Toggle with defaults filled in' {
        $t = $byId['good-registry']
        $t.Kind | Should Be 'Toggle'
        $t.Reboot | Should Be $false
        $t.Legacy | Should Be $false
        $t.Button | Should Be 'Run'
        $t.Source | Should Be (Join-Path $Fixtures 'Optimize\Gaming\GoodRegistry.ps1')
        , $t.Registry | Should BeOfType [hashtable[]]
        $t.Registry.Count | Should Be 1
    }

    It 'loads exactly the valid fixtures' {
        ($r.Tweaks.Id | Sort-Object) -join ',' | Should Be 'good-action,good-choice,good-group/Akari.Test.One,good-group/Akari.Test.Two,good-registry,good-winget,no-detect'
    }

    It 'builds a winget install: Apply installs each id then runs After, Detect = all installed' {
        $w = $byId['good-winget']
        "$($w.Apply)" | Should Be "Install-AkariWingetPackage 'Akari.Test.One'`nInstall-AkariWingetPackage 'Akari.Test++'`n 'after' "
        "$($w.Detect)" | Should Be "(Test-AkariWingetInstalled 'Akari.Test.One') -and (Test-AkariWingetInstalled 'Akari.Test++')"
    }

    It 'expands a data-list Group into Entries: Actions with Remove, Risk, Keep and the package' {
        $one = $byId['good-group/Akari.Test.One']
        $one.Kind | Should Be 'Action'
        $one.Button | Should Be 'Remove'
        $one.Name | Should Be 'One'
        $one.Risk | Should Be 'Safe'
        $one.Group | Should Be 'good-group'
        $one.Package | Should Be 'Akari.Test.One'
        $one.Keep | Should Be $false
        "$($one.Apply)" | Should Be "Remove-AkariAppx 'Akari.Test.One'"
        $two = $byId['good-group/Akari.Test.Two']
        $two.Name | Should Be 'Akari.Test.Two'
        $two.Keep | Should Be $true
        @($r.Groups).Count | Should Be 1
    }

    It 'resolves an Entry id the data file does not list, and nothing for other ids' {
        $e = Resolve-AkariEntry $r.Groups 'good-group/Some.Other.App'
        $e.Package | Should Be 'Some.Other.App'
        $e.Risk | Should Be 'Caution'
        Resolve-AkariEntry $r.Groups 'zz-fake-id' | Should BeNullOrEmpty
        Resolve-AkariEntry $r.Groups 'good-group/' | Should BeNullOrEmpty
    }

    It 'warns about a Toggle with no Detect and no Registry' {
        $p = @(Get-Problem 'NoDetect.ps1')
        $p.Count | Should Be 1
        $p[0].Level | Should Be 'Warning'
    }

    It 'reports a file with a syntax error and keeps loading the rest' {
        $p = @(Get-Problem 'Syntax.ps1')
        $p.Count | Should Be 1
        $p[0].Level | Should Be 'Error'
        $byId.ContainsKey('good-registry') | Should Be $true
    }

    # each bad fixture is rejected with one Error naming the broken rule
    $rejected = @(
        @{ File = 'MissingName.ps1'; Says = 'Name' }
        @{ File = 'BadId.ps1'; Says = 'kebab-case' }
        @{ File = 'BadRisk.ps1'; Says = 'Risk' }
        @{ File = 'GroupKind.ps1'; Says = 'EntryKind' }
        @{ File = 'WrongFolder.ps1'; Says = 'Category' }
        @{ File = 'NoRevert.ps1'; Says = 'Revert' }
        @{ File = 'RegNoDefault.ps1'; Says = 'Default' }
        @{ File = 'ChoiceBadRec.ps1'; Says = 'Recommended' }
        @{ File = 'ActionNoReason.ps1'; Says = '# Action:' }
        @{ File = 'Interactive.ps1'; Says = 'Pause' }
        @{ File = 'ZDup.ps1'; Says = 'good-registry' }
        @{ File = 'WingetApply.ps1'; Says = 'After' }
        @{ File = 'AfterNoWinget.ps1'; Says = 'only for an Action with Winget' }
        @{ File = 'WingetBadId.ps1'; Says = 'not a package id' }
    )
    foreach ($c in $rejected) {
        It "rejects $($c.File)" {
            $p = @(Get-Problem $c.File)
            $p.Count | Should Be 1
            $p[0].Level | Should Be 'Error'
            $p[0].Message | Should Match $c.Says
        }
    }
}
