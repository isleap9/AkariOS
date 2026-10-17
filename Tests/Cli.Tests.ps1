$Akari = Join-Path (Split-Path $PSScriptRoot) 'Akari.ps1'

# runs Akari.ps1 in a fresh, non-elevated powershell; returns exit code and output lines
function Invoke-Akari([string[]]$CliArgs) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Akari @CliArgs 2>&1 | ForEach-Object { "$_" }
    @{ Code = $LASTEXITCODE; Out = @($out) }
}

Describe 'Akari.ps1 -List' {
    $r = Invoke-Akari @('-List')

    It 'exits 0' { $r.Code | Should Be 0 }

    It 'lists the sample tweaks' {
        $text = $r.Out -join "`n"
        foreach ($id in 'disable-game-dvr', 'disable-memory-compression', 'win32-priority-separation') { $text | Should Match $id }
    }

    It 'shows a State even when Detect needs admin' {
        ($r.Out | Where-Object { $_ -match 'disable-memory-compression' }) | Should Match '(Optimized|Default|Custom|Unknown)'
    }

    It 'loads the real Tweaks tree with no Errors' {
        @($r.Out | Where-Object { $_ -match '^Error:' }).Count | Should Be 0
    }
}

Describe 'Akari.ps1 -Apply without elevation' {
    It 'refuses with exit code 2' {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
        if ($isAdmin) { Set-TestInconclusive 'test session is elevated'; return }
        # a fake id: this test must never be able to change the machine, even if the elevation check breaks
        $r = Invoke-Akari @('-Apply', 'no-such-tweak')
        $r.Code | Should Be 2
        ($r.Out -join "`n") | Should Match 'elevated'
    }
}
