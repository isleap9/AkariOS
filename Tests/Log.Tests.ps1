$Core = Join-Path (Split-Path $PSScriptRoot) 'Core'

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
