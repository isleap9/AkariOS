$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# The Core helpers behind Advanced > Features (winutil W2): features and capabilities turned on, a Windows source for
# .NET 3.5, a daily task, an administrators-only file. Every DISM and task cmdlet is mocked: nothing on this PC changes.

Describe 'Windows features and capabilities (Core\Appx.ps1)' {
    . "$Core\Appx.ps1"

    Context 'Get-AkariFeatureState' {
        Mock Get-WindowsOptionalFeature { [pscustomobject]@{ FeatureName = $FeatureName; State = 'EnablePending' } } -ParameterFilter { $FeatureName -eq 'NetFx3' }
        Mock Get-WindowsOptionalFeature { } -ParameterFilter { $FeatureName -eq 'Missing-Feature' }
        It 'says a feature''s state as DISM names it' { Get-AkariFeatureState 'NetFx3' | Should Be 'EnablePending' }
        It 'says nothing for a feature this Windows lacks' { Get-AkariFeatureState 'Missing-Feature' | Should BeNullOrEmpty }
    }

    Context 'Enable-AkariFeature' {
        Mock Enable-WindowsOptionalFeature { }
        It 'turns it on with its parents and no restart' {
            Enable-AkariFeature 'Microsoft-Hyper-V-All'
            Assert-MockCalled Enable-WindowsOptionalFeature -Exactly 1 -ParameterFilter {
                $Online -and $FeatureName -eq 'Microsoft-Hyper-V-All' -and $All -and $NoRestart -and -not $Source -and -not $LimitAccess
            }
        }
        It 'takes its files from a Windows source when given one, never from Windows Update' {
            Enable-AkariFeature 'NetFx3' 'D:\sources\sxs'
            Assert-MockCalled Enable-WindowsOptionalFeature -Exactly 1 -ParameterFilter {
                $FeatureName -eq 'NetFx3' -and $Source -eq 'D:\sources\sxs' -and $LimitAccess -and $All -and $NoRestart
            }
        }
    }

    Context 'Get-AkariCapabilityState and Add-AkariCapability' {
        Mock Get-WindowsCapability { [pscustomobject]@{ Name = $Name; State = 'NotPresent' } } -ParameterFilter { $Name -eq 'OpenSSH.Server~~~~0.0.1.0' }
        Mock Get-WindowsCapability { } -ParameterFilter { $Name -eq 'No.Such~~~~0.0.1.0' }
        Mock Add-WindowsCapability { }
        It 'says a capability''s state, nothing for one Windows lacks' {
            Get-AkariCapabilityState 'OpenSSH.Server~~~~0.0.1.0' | Should Be 'NotPresent'
            Get-AkariCapabilityState 'No.Such~~~~0.0.1.0' | Should BeNullOrEmpty
        }
        It 'adds a capability' {
            Add-AkariCapability 'OpenSSH.Server~~~~0.0.1.0'
            Assert-MockCalled Add-WindowsCapability -Exactly 1 -ParameterFilter { $Online -and $Name -eq 'OpenSSH.Server~~~~0.0.1.0' }
        }
    }

    Context 'Find-AkariWindowsSource' {
        foreach ($d in 'usb', 'iso\sources\sxs', 'other\sources') { New-Item -ItemType Directory -Path "TestDrive:\$d" -Force | Out-Null }
        $usb = (Get-Item 'TestDrive:\usb').FullName; $iso = (Get-Item 'TestDrive:\iso').FullName; $other = (Get-Item 'TestDrive:\other').FullName
        It 'finds the first drive holding a Windows setup''s sources\sxs' {
            Find-AkariWindowsSource @("$usb\", "$other\", "$iso\") | Should Be (Join-Path $iso 'sources\sxs')
        }
        It 'finds none when no drive has one' { Find-AkariWindowsSource @("$usb\", "$other\") | Should BeNullOrEmpty }
    }
}

Describe 'A daily task and an administrators-only file (Core\System.ps1)' {
    foreach ($f in 'Log', 'Trusted', 'Registry', 'System') { . "$Core\$f.ps1" }

    Context 'Register-AkariDailyTask and Unregister-AkariTask' {
        Mock Register-ScheduledTask { }
        Mock Unregister-ScheduledTask { }
        It 'registers a task that runs a program every day at a time, as SYSTEM' {
            Register-AkariDailyTask '\AkariOS\' 'RegistryBackup' 'schtasks.exe' '/run /i /tn "\Microsoft\Windows\Registry\RegIdleBackup"' '00:30' 'Backs up the registry'
            Assert-MockCalled Register-ScheduledTask -Exactly 1 -ParameterFilter {
                $TaskPath -eq '\AkariOS\' -and $TaskName -eq 'RegistryBackup' -and $User -eq 'NT AUTHORITY\SYSTEM' -and $Force -and
                $Description -eq 'Backs up the registry' -and $Action.Execute -eq 'schtasks.exe' -and
                $Action.Arguments -eq '/run /i /tn "\Microsoft\Windows\Registry\RegIdleBackup"' -and
                $Trigger.DaysInterval -eq 1 -and ([datetime]$Trigger.StartBoundary).ToString('HH:mm') -eq '00:30' -and $Settings.StartWhenAvailable
            }
        }
        It 'unregisters a task without asking' {
            Unregister-AkariTask '\AkariOS\' 'RegistryBackup'
            Assert-MockCalled Unregister-ScheduledTask -Exactly 1 -ParameterFilter { $TaskPath -eq '\AkariOS\' -and $TaskName -eq 'RegistryBackup' -and -not [bool]$Confirm }
        }
    }

    Context 'Set-AkariAdminOnlyAcl' {
        $file = Join-Path (Get-Item 'TestDrive:\').FullName 'ssh\administrators_authorized_keys'
        It 'makes the file when it is missing and leaves only Administrators and SYSTEM on it, inheritance off' {
            Set-AkariAdminOnlyAcl $file
            Test-Path -LiteralPath $file | Should Be $true
            $acl = Get-Acl -LiteralPath $file
            $acl.AreAccessRulesProtected | Should Be $true
            $sids = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | ForEach-Object { "$($_.IdentityReference)|$($_.FileSystemRights)|$($_.AccessControlType)" } | Sort-Object)
            $sids -join ';' | Should Be 'S-1-5-18|FullControl|Allow;S-1-5-32-544|FullControl|Allow'
        }
    }
}
