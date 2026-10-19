# Action: brlapi comes back only with a Windows reinstall or repair; Akari has no Revert for it.
# Ported from FR33THY Ultimate "bloatware" (legacy apps).
@{
    Id          = 'remove-brlapi'
    Name        = 'BRLTTY braille driver'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Safe'
    Description = 'The brlapi service and its brltty folder, for braille displays.'
    Detect      = { -not (Get-Service 'brlapi' -ErrorAction SilentlyContinue) -and -not (Test-Path "$env:SystemRoot\brltty") }
    Apply       = {
        Stop-Service 'brlapi' -Force -ErrorAction SilentlyContinue
        Remove-AkariService 'brlapi'
        if (Test-Path "$env:SystemRoot\brltty") {
            # owned by TrustedInstaller: take it for Administrators first
            & takeown.exe /f "$env:SystemRoot\brltty" /r /d y 2>&1 | Out-Null
            & icacls.exe "$env:SystemRoot\brltty" /grant '*S-1-5-32-544:F' /t 2>&1 | Out-Null
            Remove-Item "$env:SystemRoot\brltty" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
