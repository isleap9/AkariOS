$Core = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Core'

# bcdedit and shutdown are mocked; RunOnce writes go to HKCU:\Software\AkariTest only
Describe 'Phases' {
    foreach ($f in 'Log', 'Registry', 'Phases') { . "$Core\$f.ps1" }
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"

    try {
        It 'builds the resume command for Akari.ps1' {
            Get-AkariResumeCommand 'C:\My Tools\AkariOS\Akari.ps1' '-Resume' |
                Should Be 'powershell.exe -nop -ep bypass -WindowStyle Maximized -File "C:\My Tools\AkariOS\Akari.ps1" -Resume'
        }

        It 'registers a RunOnce value' {
            Register-AkariResume '*!akari-test' 'cmd /c echo hi' $k
            Get-AkariRegValue $k '*!akari-test' | Should Be 'cmd /c echo hi'
        }

        # Invoke-AkariBcdEdit is a PowerShell function, so the mock always intercepts it: bcdedit never runs here
        It 'turns Safe Mode on with bcdedit' {
            Mock Invoke-AkariBcdEdit { 0 }
            { Set-AkariSafeBoot $true } | Should Not Throw
            Assert-MockCalled Invoke-AkariBcdEdit -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments -eq '/set {current} safeboot minimal' }
        }

        It 'throws when bcdedit cannot turn Safe Mode on; turning it off when it is off is fine' {
            Mock Invoke-AkariBcdEdit { 1 }
            { Set-AkariSafeBoot $true } | Should Throw 'Safe Mode on'
            { Set-AkariSafeBoot $false } | Should Not Throw
            Assert-MockCalled Invoke-AkariBcdEdit -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments -eq '/deletevalue {current} safeboot' }
        }
    } finally {
        Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue
    }
}
