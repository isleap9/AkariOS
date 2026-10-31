$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# The Services and Scheduled tasks pages: Core\System.ps1's service and task helpers (a test services root, the task
# cmdlets mocked) and the pages' pure parts (UI\ServicesPage.ps1, UI\TasksPage.ps1). No WPF, no real service or task.

Describe 'Service and task helpers (Core)' {
    foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'System') { . "$Core\$f.ps1" }
    Mock Run-Trusted { }
    Mock Write-ErrLog { }

    It 'turns Win32_Service start modes into startup types and back' {
        ConvertTo-AkariStartType 'Auto' $false | Should Be 'Automatic'
        ConvertTo-AkariStartType 'Auto' $true | Should Be 'AutomaticDelayed'
        ConvertTo-AkariStartType 'Manual' $true | Should Be 'Manual'
        ConvertTo-AkariStartType 'Disabled' $false | Should Be 'Disabled'
        ConvertTo-AkariStartType 'Boot' $false | Should Be 'Boot'
        (ConvertFrom-AkariStartType 'AutomaticDelayed').Start | Should Be 2
        (ConvertFrom-AkariStartType 'AutomaticDelayed').Delayed | Should Be 1
        (ConvertFrom-AkariStartType 'Disabled').Start | Should Be 4
        { ConvertFrom-AkariStartType 'Boot' } | Should Throw
    }

    It 'finds the template of a per-user service instance' {
        Get-AkariServiceTemplate 'cbdhsvc_4f2a1' | Should Be 'cbdhsvc'
        Get-AkariServiceTemplate 'Spooler' | Should Be ''
        Get-AkariServiceTemplate 'Some_Service' | Should Be ''
    }

    Context 'Set-AkariServiceStart (a test services root)' {
        $AkariServicesRoot = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
        foreach ($n in 'Spooler', 'cbdhsvc', 'cbdhsvc_4f2a1') {
            New-Item "$AkariServicesRoot\$n" -Force | Out-Null
            New-ItemProperty "$AkariServicesRoot\$n" -Name Start -Value 2 -PropertyType DWord -Force | Out-Null
        }
        It 'writes Start and DelayedAutostart' {
            Set-AkariServiceStart 'Spooler' 'AutomaticDelayed'
            (Get-ItemProperty "$AkariServicesRoot\Spooler").Start | Should Be 2
            (Get-ItemProperty "$AkariServicesRoot\Spooler").DelayedAutostart | Should Be 1
            Set-AkariServiceStart 'Spooler' 'Disabled'
            (Get-ItemProperty "$AkariServicesRoot\Spooler").Start | Should Be 4
            (Get-ItemProperty "$AkariServicesRoot\Spooler").DelayedAutostart | Should Be 0
        }
        It 'sets a per-user instance and its template' {
            Set-AkariServiceStart 'cbdhsvc_4f2a1' 'Manual'
            (Get-ItemProperty "$AkariServicesRoot\cbdhsvc_4f2a1").Start | Should Be 3
            (Get-ItemProperty "$AkariServicesRoot\cbdhsvc").Start | Should Be 3
        }
        It 'throws for a service that is not there' {
            { Set-AkariServiceStart 'NoSuchService' 'Manual' } | Should Throw
        }
        Remove-Item $AkariServicesRoot -Recurse -Force
    }

    Context 'Set-AkariTaskEnabled (the task cmdlets mocked)' {
        It 'turns a task off as admin' {
            Mock Disable-ScheduledTask { }
            Mock Get-ScheduledTask { [pscustomobject]@{ State = 'Disabled' } }
            Set-AkariTaskEnabled '\Microsoft\Windows\X\' 'T' $false
            Assert-MockCalled Disable-ScheduledTask -Scope It -Exactly 1
            Assert-MockCalled Run-Trusted -Scope It -Exactly 0
        }
        It 'goes through TrustedInstaller when an admin may not change it' {
            Mock Disable-ScheduledTask { throw 'Access is denied.' }
            Mock Get-ScheduledTask { [pscustomobject]@{ State = 'Disabled' } }
            Set-AkariTaskEnabled '\Microsoft\Windows\UpdateOrchestrator\' 'Schedule Scan' $false
            Assert-MockCalled Run-Trusted -Scope It -Exactly 1 -ParameterFilter { $command -eq "schtasks.exe /change /tn '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan' /disable" }
        }
        It 'throws when the task stays as it was' {
            Mock Enable-ScheduledTask { throw 'Access is denied.' }
            Mock Get-ScheduledTask { [pscustomobject]@{ State = 'Disabled' } }
            { Set-AkariTaskEnabled '\X\' 'T' $true } | Should Throw
        }
    }

    It 'leaves plain text as it is' {
        Resolve-AkariIndirectString 'Keeps your PC up to date' | Should Be 'Keeps your PC up to date'
        Resolve-AkariIndirectString '' | Should Be ''
    }
}

Describe 'Services and Scheduled tasks pages (pure parts)' {
    foreach ($f in 'Log', 'Registry', 'Loader', 'System') { . "$Core\$f.ps1" }
    . "$Root\UI\Catalogue.ps1"
    . "$Root\UI\ServicesPage.ps1"
    . "$Root\UI\TasksPage.ps1"
    $svc = { param($n, $start, $status = 'Stopped', $stop = $true, $d = '') [pscustomobject]@{ Name = $n; DisplayName = "$n service"; Description = $d; Start = $start; Status = $status; CanStop = $stop } }
    $list = @(
        & $svc 'Spooler' 'Automatic' 'Running' $true 'Print jobs'
        & $svc 'BITS' 'AutomaticDelayed' 'Running'
        & $svc 'Fax' 'Disabled'
        & $svc 'cbdhsvc_4f2a1' 'Manual'
        & $svc 'Odd' 'Boot' 'Running' $false
    )
    $defaults = @{ Spooler = 2; BITS = 2; Fax = 3; cbdhsvc = 2 }

    It 'puts the two tweaks on the Services and Scheduled tasks pages' {
        $tw = Join-Path $Root 'Tweaks'
        $t = @(
            Import-AkariTweakFile (Join-Path $tw 'Advanced\Services\ServicesOff.ps1') $tw
            Import-AkariTweakFile (Join-Path $tw 'Advanced\Scheduled tasks\RemoveScheduledTasks.ps1') $tw
        )
        $keys = @((Get-AkariCataloguePages $t).Pages | ForEach-Object { $_.Key })
        foreach ($k in $AkariCatalogueLists.Keys) { $keys -contains $k | Should Be $true }
    }

    It 'reads the Windows defaults advanced-services-off knows' {
        $d = Get-AkariServiceDefaults (Join-Path $Root $AkariServiceDefaultsPath)
        $d['BITS'] | Should Be 2
        $d.Count -gt 100 | Should Be $true
    }

    It 'filters by status, startup type and search, by display name' {
        @(Get-AkariServiceView $list 'All' '' $defaults).Count | Should Be 5
        (@(Get-AkariServiceView $list 'All' '' $defaults) | ForEach-Object { $_.Name }) -join ',' | Should Be 'BITS,cbdhsvc_4f2a1,Fax,Odd,Spooler'
        (@(Get-AkariServiceView $list 'Running' '' $defaults) | ForEach-Object { $_.Name }) -join ',' | Should Be 'BITS,Odd,Spooler'
        (@(Get-AkariServiceView $list 'Automatic' '' $defaults) | ForEach-Object { $_.Name }) -join ',' | Should Be 'BITS,Spooler'
        (@(Get-AkariServiceView $list 'Disabled' '' $defaults) | ForEach-Object { $_.Name }) -join ',' | Should Be 'Fax'
        (@(Get-AkariServiceView $list 'All' 'print' $defaults) | ForEach-Object { $_.Name }) -join ',' | Should Be 'Spooler'
        @(Get-AkariServiceView $list 'All' '[x' $defaults).Count | Should Be 0
    }

    It 'tells a startup type that is not the Windows default (delayed counts as automatic; instances by their template)' {
        (@(Get-AkariServiceView $list 'Changed' '' $defaults) | ForEach-Object { $_.Name }) -join ',' | Should Be 'cbdhsvc_4f2a1,Fax'
        Get-AkariServiceDefault $list[3] $defaults | Should Be 2
        Get-AkariServiceDefault $list[4] $defaults | Should Be $null
    }

    It 'lists by default only the services FR33THY or ZOICWARE change, with what each sets' {
        $sug = Get-AkariServiceSuggestions (Join-Path $Root $AkariServiceDefaultsPath)
        $sug['Spooler'] -join ', ' | Should Be 'Off (FR33THY): Disabled, Light (ZOICWARE): Disabled, Manual (ZOICWARE): Manual'
        $sug['CryptSvc'] -join ', ' | Should Be 'Manual (ZOICWARE): Manual'
        $sug.ContainsKey('RpcSs') | Should Be $false
        # cbdhsvc_4f2a1: its template; Odd: nobody's
        (@(Get-AkariServiceView $list 'All' '' $defaults $sug) | ForEach-Object { $_.Name }) -join ',' | Should Be 'BITS,cbdhsvc_4f2a1,Fax,Spooler'
        @(Get-AkariServiceView $list 'All' '' $defaults $null).Count | Should Be 5
    }

    It 'offers Stop, Start or nothing' {
        Get-AkariServiceAction $list[0] | Should Be 'Stop'
        Get-AkariServiceAction $list[2] | Should Be ''
        Get-AkariServiceAction $list[3] | Should Be 'Start'
        Get-AkariServiceAction $list[4] | Should Be ''
    }

    It 'asks before disabling or stopping a service Windows needs, not otherwise' {
        $rpc = & $svc 'RpcSs' 'Automatic' 'Running'
        Get-AkariServiceConfirm $rpc 'StartType' 'Disabled' | Should Match 'Windows needs'
        Get-AkariServiceConfirm $rpc 'Control' 'Stop' | Should Match 'Stop it anyway'
        Get-AkariServiceConfirm $rpc 'StartType' 'Manual' | Should Be ''
        Get-AkariServiceConfirm $list[0] 'StartType' 'Disabled' | Should Be ''
    }

    It 'filters the tasks: on, off, Windows'' own, the apps'', search' {
        $tasks = @(
            [pscustomobject]@{ Path = '\Microsoft\Windows\Defrag\'; Name = 'ScheduledDefrag'; Enabled = $true; Description = 'Optimizes drives' }
            [pscustomobject]@{ Path = '\'; Name = 'GoogleUpdateTaskMachineUA'; Enabled = $true; Description = '' }
            [pscustomobject]@{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater'; Enabled = $false; Description = '' }
        )
        (@(Get-AkariTaskView $tasks 'All' '') | ForEach-Object { $_.Name }) -join ',' | Should Be 'GoogleUpdateTaskMachineUA,ProgramDataUpdater,ScheduledDefrag'
        (@(Get-AkariTaskView $tasks 'Disabled' '') | ForEach-Object { $_.Name }) -join ',' | Should Be 'ProgramDataUpdater'
        (@(Get-AkariTaskView $tasks 'Microsoft' '') | ForEach-Object { $_.Name }) -join ',' | Should Be 'ProgramDataUpdater,ScheduledDefrag'
        (@(Get-AkariTaskView $tasks 'Other' '') | ForEach-Object { $_.Name }) -join ',' | Should Be 'GoogleUpdateTaskMachineUA'
        (@(Get-AkariTaskView $tasks 'All' 'defrag') | ForEach-Object { $_.Name }) -join ',' | Should Be 'ScheduledDefrag'
        Get-AkariTaskKey $tasks[0] | Should Be '\Microsoft\Windows\Defrag\ScheduledDefrag'
    }

    It 'lists by default only the tasks FR33THY or ZOICWARE turn off (folders and wildcards), with who and why' {
        $sug = @(Get-AkariTaskSuggestions (Join-Path $Root $AkariTaskSuggestPath))
        $sug.Count -gt 10 | Should Be $true
        @($sug | Where-Object { -not ($_.Path -like '\*\' -and $_.Name -and $_.Source -and $_.Note) }).Count | Should Be 0
        $tasks = @(
            [pscustomobject]@{ Path = '\Microsoft\Windows\Defrag\'; Name = 'ScheduledDefrag'; Enabled = $true; Description = '' }
            [pscustomobject]@{ Path = '\Microsoft\Windows\UpdateOrchestrator\'; Name = 'Schedule Scan'; Enabled = $true; Description = '' }
            [pscustomobject]@{ Path = '\Microsoft\Windows\Windows Defender\'; Name = 'Windows Defender Cleanup'; Enabled = $true; Description = '' }
            [pscustomobject]@{ Path = '\Microsoft\Windows\TextServicesFramework\'; Name = 'MsCtfMonitor'; Enabled = $true; Description = '' }
        )
        (@(Get-AkariTaskView $tasks 'All' '' $sug) | ForEach-Object { $_.Name }) -join ',' | Should Be 'ScheduledDefrag,Schedule Scan,Windows Defender Cleanup'
        @(Get-AkariTaskView $tasks 'All' '' $null).Count | Should Be 4
        (Get-AkariTaskSuggestion $tasks[1] $sug).Note | Should Be 'Windows Update'
        Get-AkariTaskSuggestion $tasks[3] $sug | Should Be $null
    }
}
