$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'

Describe 'Console banner (Assets\ascii.txt)' {
    . "$Core\Log.ps1"

    It 'drops blank rows and the common left margin' {
        Set-Content "$TestDrive\art.txt" @('', '   ', '      .  ', '     ...', '    +++=  ', '', '')
        (Get-AkariBannerArt "$TestDrive\art.txt" 1 1) -join '|' | Should Be '  .| ...|++++'
    }

    It 'scales height and width, each character the most common in its block (= counts as +)' {
        Set-Content "$TestDrive\sq.txt" @('..++', '..+=', '   .', '  ==')
        (Get-AkariBannerArt "$TestDrive\sq.txt" 0.5 0.5) -join '|' | Should Be '.+| +'
    }

    It 'gives nothing for a missing file (the text banner shows instead)' {
        @(Get-AkariBannerArt "$TestDrive\none.txt").Count | Should Be 0
    }

    It 'finds the AkariOS logo next to Core and it fits a default console (80 x 30, with the lines under it)' {
        $a = @(Get-AkariBannerArt)
        $a.Count | Should BeGreaterThan 10
        $a.Count | Should BeLessThan 25
        ($a | Measure-Object Length -Maximum).Maximum | Should BeLessThan 79
    }
}

Describe 'Write-Log' {
    . "$Core\Log.ps1"

    It 'queues trimmed messages when LogQueue exists' {
        $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
        Write-Log 'hi  '
        $m = $null
        $LogQueue.TryDequeue([ref]$m) | Should Be $true
        $m | Should Be 'hi'
    }

    It 'drops blank messages' {
        $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
        Write-Log '   '
        $LogQueue.Count | Should Be 0
    }
}

Describe 'Write-Host shim without a LogQueue (CLI)' {
    It 'prints once and returns' {
        $cmd = ". '$Core\Log.ps1'; . '$Core\Compat.ps1'; Write-Host 'x'"
        $p = Start-Process powershell.exe -ArgumentList '-NoProfile', '-Command', $cmd -NoNewWindow -PassThru `
            -RedirectStandardOutput "$TestDrive\out.txt" -RedirectStandardError "$TestDrive\err.txt"
        $p.WaitForExit(10000) | Should Be $true
        @(Get-Content "$TestDrive\out.txt") | Should Be @('x')
        Get-Content "$TestDrive\err.txt" -Raw | Should BeNullOrEmpty
    }
}
