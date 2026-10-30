$Core = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Core'
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
        ($r.Tweaks.Id | Sort-Object) -join ',' | Should Be 'good-action,good-before,good-choice,good-group/Akari.Test.One,good-group/Akari.Test.Two,good-key,good-registry,good-winget,no-detect'
    }

    It 'loads a key row, a Binary value, Requires and Explorer' {
        $t = $byId['good-key']
        $t.Registry[0].ContainsKey('Name') | Should Be $false
        $t.Registry[1].Value.GetType().Name | Should Be 'Byte[]'
        , $t.Requires | Should BeOfType [string[]]
        $t.Requires -join ',' | Should Be 'Win11'
        $t.Explorer | Should Be $true
        $byId['good-registry'].Explorer | Should Be $false
    }

    It 'runs Before ahead of the winget install' {
        "$($byId['good-before'].Apply)" | Should Be " 'before' `nInstall-AkariWingetPackage 'Akari.Test.Before'`n"
    }

    It 'reads Ported.psd1, values always as lists' {
        $r.Ported['legacy-toggle'] -join ',' | Should Be 'good-registry,good-key'
        , $r.Ported['no-such-legacy'] | Should BeOfType [string[]]
    }

    It 'reports Ported ids that do not exist on either side' {
        . "$Core\Legacy.ps1"
        $all = @(Import-AkariLegacyTweaks (Join-Path $PSScriptRoot 'Fixtures\Legacy')) + @($r.Tweaks)
        $p = @(Test-AkariPorted $r.Ported $all | ForEach-Object { $_.Message } | Sort-Object)
        $p -join ' | ' | Should Be "'legacy-group' -> 'no-such-new' is not a one-file Tweak id | 'no-such-legacy' is not a legacy id"
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
        @{ File = 'ChoiceValueRegistry.ps1'; Says = 'a Choice with Value needs Apply and Revert, and no Registry' }
        @{ File = 'ActionNoReason.ps1'; Says = '# Action:' }
        @{ File = 'Interactive.ps1'; Says = 'Pause' }
        @{ File = 'ZDup.ps1'; Says = 'good-registry' }
        @{ File = 'WingetApply.ps1'; Says = 'After' }
        @{ File = 'AfterNoWinget.ps1'; Says = 'only for an Action with Winget' }
        @{ File = 'WingetBadId.ps1'; Says = 'not a package id' }
        @{ File = 'BadRequires.ps1'; Says = "Requires 'Mars'" }
        @{ File = 'KeyRowBad.ps1'; Says = "Value and Default must be 'Key'" }
        @{ File = 'BeforeNoWinget.ps1'; Says = 'only for an Action with Winget' }
        @{ File = 'ToggleAfterNoRegistry.ps1'; Says = 'After on a Toggle needs Registry' }
        @{ File = 'PrepareNoSafeMode.ps1'; Says = 'Prepare is only for a SafeMode Tweak' }
        @{ File = 'ZOwner.ps1'; Says = "owned by 'good-registry'" }
        @{ File = 'ZOwnerKey.ps1'; Says = "owned by 'good-key'" }
    )
    It 'reports a registry clash without loading the second Tweak' {
        $byId.ContainsKey('z-owner') | Should Be $false
        $byId.ContainsKey('z-owner-key') | Should Be $false
    }

    foreach ($c in $rejected) {
        It "rejects $($c.File)" {
            $p = @(Get-Problem $c.File)
            $p.Count | Should Be 1
            $p[0].Level | Should Be 'Error'
            $p[0].Message | Should Match $c.Says
        }
    }
}

Describe 'Find-AkariRegistryOwner' {
    . "$Core\Loader.ps1"
    $ix = New-AkariOwnerIndex
    Add-AkariRegistryOwner $ix @{ Id = 'val'; Registry = @(@{ Path = 'HKCU:\Software\A'; Name = 'V'; Value = 1 }) }
    Add-AkariRegistryOwner $ix @{ Id = 'key'; Registry = @(@{ Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\K\'; Value = 'Key'; Default = $null }) }
    $find = { param([hashtable]$Row) Find-AkariRegistryOwner @{ Id = 'new'; Registry = @($Row) } $ix }

    It 'finds the same value (any case, long or short hive name)' {
        & $find @{ Path = 'HKEY_CURRENT_USER\software\a'; Name = 'v' } | Should Be 'val'
    }
    It 'finds a value or key inside an earlier key row' {
        & $find @{ Path = 'HKLM:\SOFTWARE\K'; Name = 'X' } | Should Be 'key'
        & $find @{ Path = 'HKLM:\SOFTWARE\K\Sub'; Value = 'Key'; Default = $null } | Should Be 'key'
    }
    It 'finds a key row holding an earlier value' {
        & $find @{ Path = 'HKCU:\Software'; Value = $null; Default = 'Key' } | Should Be 'val'
    }
    It 'lets other values and neighbouring keys through' {
        & $find @{ Path = 'HKCU:\Software\A'; Name = 'Other' } | Should BeNullOrEmpty
        & $find @{ Path = 'HKCU:\Software\AB'; Value = 'Key'; Default = $null } | Should BeNullOrEmpty
        & $find @{ Path = 'HKLM:\SOFTWARE\KK'; Name = 'X' } | Should BeNullOrEmpty
        & $find @{ Path = 'HKLM:\SOFTWARE'; Name = 'K' } | Should BeNullOrEmpty
    }
}

Describe 'The real Tweaks tree' {
    . "$Core\Loader.ps1"; . "$Core\Legacy.ps1"
    $root = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Tweaks'
    $r = Get-AkariTweaks $root
    $all = @(Import-AkariLegacyTweaks $root) + @($r.Tweaks)

    It 'loads with no Errors, so no registry value has two owners' {
        @($r.Problems | Where-Object { $_.Level -eq 'Error' } | ForEach-Object { "$($_.File): $($_.Message)" }) -join "`n" | Should Be ''
    }

    It 'maps every Ported.psd1 id to a real legacy id and real one-file ids' {
        @(Test-AkariPorted $r.Ported $all | ForEach-Object { $_.Message }) -join "`n" | Should Be ''
        $r.Ported['edge-webview'] -join ',' | Should Be 'remove-edge,remove-webview2,install-microsoft-edge,install-webview2-runtime'
    }

    It 'puts Edge and WebView2 back from Downloads, after lifting the removal''s block' {
        $edge = $all | Where-Object { $_.Id -eq 'install-microsoft-edge' }
        "$($edge.Apply)" | Should Match "(?s)Install\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062\}.*Install-AkariWingetPackage 'Microsoft\.Edge'"
        $wv = $all | Where-Object { $_.Id -eq 'install-webview2-runtime' }
        "$($wv.Apply)" | Should Match "(?s)Install\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5\}.*Install-AkariWingetPackage 'Microsoft\.EdgeWebView2Runtime'"
    }
}
