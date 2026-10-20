# One-click's steptwo.ps1 (isleap9/Akari-OS): "remove 3rd party startup apps" and "scheduled tasks".
# Action: what it
# removes was put there by other programs, nothing to put back.
@{
    Id          = 'oneclick-startup-cleanup'
    Name        = 'Remove third-party startup entries and tasks'
    Section     = 'OneClick'
    Category    = 'Finish'
    Kind        = 'Action'
    Risk        = 'Advanced'
    Description = 'Empties the Run / RunOnce keys and the Startup folders, and deletes every scheduled task outside \Microsoft.'
    Apply       = {
        foreach ($k in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunNotification', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
            $p = Resolve-AkariRegPath $k
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
            New-Item -Path $p -Force | Out-Null
        }
        foreach ($d in "$(Get-AkariUserFolder 'AppData')\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp") {
            if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
        }
        # the task cache is TrustedInstaller's; the task files are the administrators'
        $tree = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree'
        foreach ($k in @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath $tree) -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -ne 'Microsoft' })) {
            Run-Trusted "Remove-Item -LiteralPath 'Registry::$($k.Name)' -Recurse -Force"
        }
        Get-ChildItem -LiteralPath "$env:SystemRoot\System32\Tasks" -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'Microsoft' } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
