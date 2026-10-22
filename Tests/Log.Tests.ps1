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

Describe 'Write-AkariProblems (loader Problems)' {
    . "$Core\Log.ps1"
    $AkariLogFile = "$TestDrive\problems.log"

    It 'logs Warnings to akari.log only and shows Errors' {
        $shown = [Collections.Generic.List[string]]::new()
        Write-AkariProblems @(
            [pscustomobject]@{ File = 'a.ps1'; Level = 'Warning'; Message = 'no Detect' }
            [pscustomobject]@{ File = 'b.ps1'; Level = 'Error'; Message = 'broken' }) { param($m) $shown.Add($m) }
        $shown -join '|' | Should Be 'Error: b.ps1: broken'
        Get-Content $AkariLogFile -Raw | Should Match 'Warning: a\.ps1: no Detect'
    }
}

Describe 'Write-AkariCrash (Akari.ps1 trap)' {
    It 'without WPF (CLI, -Resume): logs the error to akari.log and prints it, no message box' {
        $log = "$TestDrive\crash.log"
        $cmd = "`$AkariLogFile = '$log'; . '$Core\Log.ps1'; try { throw 'boom' } catch { Write-AkariCrash `$_ }"
        $p = Start-Process powershell.exe -ArgumentList '-NoProfile', '-Command', $cmd -NoNewWindow -PassThru `
            -RedirectStandardOutput "$TestDrive\out.txt" -RedirectStandardError "$TestDrive\err.txt"
        $p.WaitForExit(10000) | Should Be $true
        Get-Content $log -Raw | Should Match 'boom'
        Get-Content "$TestDrive\err.txt" -Raw | Should Match 'Akari hit an error:.*boom'
        Get-Content "$TestDrive\err.txt" -Raw | Should Not Match 'MessageBox'
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
