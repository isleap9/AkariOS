$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

Describe 'Import-AkariLegacyTweaks' {
    . "$Core\Loader.ps1"; . "$Core\Legacy.ps1"
    $list = @(Import-AkariLegacyTweaks (Join-Path $PSScriptRoot 'Fixtures\Legacy'))

    It 'loads every Add-Tweak call in file order' {
        ($list | ForEach-Object { $_.Id }) -join ',' | Should Be 'legacy-toggle,legacy-group'
    }

    It 'puts the old page name in Section and marks them Legacy' {
        $list[0].Section | Should Be 'Windows'
        $list[1].Section | Should Be 'Advanced'
        $list[0].Legacy | Should Be $true
        $list[0].Kind | Should Be 'Toggle'
    }

    It 'keeps Group actions with their Block' {
        $list[1].Actions[0].Block | Should BeOfType [scriptblock]
    }
}

Describe 'Legacy is frozen (ADR 0004)' {
    . "$Core\Loader.ps1"; . "$Core\Legacy.ps1"
    $real = @(Import-AkariLegacyTweaks (Join-Path $Root 'Tweaks') | ForEach-Object { $_.Id })
    $want = @(Get-Content (Join-Path $PSScriptRoot 'Fixtures\legacy-ids.txt') | Where-Object { $_ -and $_ -notlike '#*' })

    It 'still loads every legacy entry of the import (none deleted by a port)' {
        @($want | Where-Object { $real -notcontains $_ }) -join ',' | Should Be ''
        $want.Count | Should Be 97
    }
}

Describe 'Legacy rows that restart the PC' {
    . "$Core\Loader.ps1"; . "$Core\Legacy.ps1"; . "$Core\Runner.ps1"
    $all = @(Import-AkariLegacyTweaks (Join-Path $Root 'Tweaks'))
    It 'are known, so a Run puts them last (Safe Mode: defender, adv-defender, services; BIOS: bios-check, to-bios)' {
        (@($all | Where-Object { (Test-AkariRestarts $_ 'Apply') -or (Test-AkariRestarts $_ 'Revert') } | ForEach-Object { $_.Id } | Sort-Object) -join ',') |
            Should Be 'adv-defender,bios-check,defender,services,to-bios'
    }
}

Describe 'Akari.ps1' {
    It 'parses' {
        $errs = $null
        [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $Root 'Akari.ps1'), [ref]$null, [ref]$errs)
        @($errs).Count | Should Be 0
    }
}
