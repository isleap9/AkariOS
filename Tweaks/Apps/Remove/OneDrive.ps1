# Action: OneDrive comes back by running OneDriveSetup.exe again, not through an Akari Revert.
# Ported from FR33THY Ultimate "bloatware" (legacy apps).
@{
    Id          = 'remove-onedrive'
    Name        = 'OneDrive'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Caution'
    Description = 'Microsoft''s cloud file sync, for every user (also the Microsoft 365 copy), with its scheduled tasks.'
    Detect      = {
        $local = Get-AkariUserFolder 'Local AppData'
        -not ((Test-Path "$local\Microsoft\OneDrive\OneDrive.exe") -or (Test-Path "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe") -or
              (Test-Path "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"))
    }
    Apply       = {
        Stop-Process -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
        foreach ($setup in "$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
            if (Test-Path $setup) { Start-Process $setup -ArgumentList '-uninstall' -Wait -WindowStyle Hidden }
        }
        # the Microsoft 365 / per-machine copy
        $local = Get-AkariUserFolder 'Local AppData'
        Get-ChildItem "$env:ProgramFiles\Microsoft OneDrive", "${env:ProgramFiles(x86)}\Microsoft OneDrive", "$local\Microsoft\OneDrive" -Filter 'OneDriveSetup.exe' -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object { Start-Process $_.FullName -ArgumentList '/uninstall /allusers' -Wait -WindowStyle Hidden }
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'OneDrive' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    }
}
