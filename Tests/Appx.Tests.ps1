$Root = Split-Path $PSScriptRoot

# every Appx cmdlet is mocked or reached only through a mocked Akari function: no real package is read or removed
Describe 'Appx' {
    . "$Root\Core\Appx.ps1"
    function P($name, [hashtable]$x = @{}) {
        $h = @{ Name = $name; PackageFullName = "${name}_1.0_x64__fake"; IsFramework = $false; IsResourcePackage = $false; NonRemovable = $false; SignatureKind = 'Store' }
        foreach ($k in $x.Keys) { $h[$k] = $x[$k] }
        [pscustomobject]$h
    }
    Mock Get-AkariAppxPackages {
        @(
            P 'Akari.Test.App'
            P 'Akari.Test.App'
            P 'Akari.Test.Framework' @{ IsFramework = $true }
            P 'Akari.Test.System' @{ SignatureKind = 'System' }
            P 'Akari.Test.Fixed' @{ NonRemovable = $true }
            P 'Microsoft.Windows.ShellExperienceHost'
            P 'Microsoft.Windows.CBSPreview'
        )
    }

    It 'lists each removable package once, without frameworks, system, non-removable or never-list packages' {
        (Get-AkariAppxInstalled) -join ',' | Should Be 'Akari.Test.App'
    }

    It 'tells installed from not installed' {
        Test-AkariAppxInstalled 'Akari.Test.App' | Should Be $true
        Test-AkariAppxInstalled 'Akari.Test.Missing' | Should Be $false
    }

    It 'never removes a package Windows needs' {
        Mock Remove-AppxPackage { }
        { Remove-AkariAppx 'Microsoft.Windows.StartMenuExperienceHost' } | Should Throw 'never removed'
        { Remove-AkariAppx 'Microsoft.Windows.CBSPreview' } | Should Throw 'never removed'
        Assert-MockCalled Remove-AppxPackage -Times 0
    }

    It 'removes every copy for all users, then the provisioned copy' {
        Mock Remove-AppxPackage { }
        Mock Get-AppxProvisionedPackage { [pscustomobject]@{ DisplayName = 'Akari.Test.App'; PackageName = 'Akari.Test.App_prov' } }
        Mock Remove-AppxProvisionedPackage { }
        Remove-AkariAppx 'Akari.Test.App'
        Assert-MockCalled Remove-AppxPackage -Times 2 -Exactly -ParameterFilter { $AllUsers -and $Package -eq 'Akari.Test.App_1.0_x64__fake' }
        Assert-MockCalled Remove-AppxProvisionedPackage -Times 1 -Exactly -ParameterFilter { $PackageName -eq 'Akari.Test.App_prov' }
    }
}

Describe 'Runner: an Action whose Detect says done' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner') { . "$Root\Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()

    It 'is Already and does not run Apply' {
        $t = ConvertTo-AkariTweak @{ Id = 'gone'; Name = 'Gone'; Kind = 'Action'; Detect = { $true }; Apply = { throw 'must not run' } } 'x' $false
        (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Already'
    }

    It 'runs Apply when Detect says not done' {
        $t = ConvertTo-AkariTweak @{ Id = 'here'; Name = 'Here'; Kind = 'Action'; Detect = { $false }; Apply = { } } 'x' $false
        (Invoke-AkariTweak $t Apply).Outcome | Should Be 'Applied'
    }
}

Describe 'The real app list' {
    . "$Root\Core\Loader.ps1"
    $r = Get-AkariTweaks "$Root\Tweaks"
    $apps = @($r.Tweaks | Where-Object { $_.Group -eq 'appx' })

    It 'loads the appx Group with its Entries and no Errors' {
        @($r.Problems | Where-Object { $_.Level -eq 'Error' }).Count | Should Be 0
        $apps.Count | Should BeGreaterThan 100
    }

    It 'marks the FR33THY keep-list' {
        (@($apps | Where-Object { $_.Keep }) | ForEach-Object { $_.Package }) -contains 'Microsoft.Windows.Photos' | Should Be $true
        ($apps | Where-Object { $_.Package -eq 'Clipchamp.Clipchamp' }).Keep | Should Be $false
    }

    It 'lists no package from the never-list' {
        . "$Root\Core\Appx.ps1"
        @($apps | Where-Object { Test-AkariAppxNever $_.Package }).Count | Should Be 0
    }

    It 'has the four parts of FR33THY''s debloat: Store apps, optional features, Windows features, legacy apps' {
        ($r.Groups | ForEach-Object { $_.EntryKind } | Sort-Object) -join ',' | Should Be 'AppxRemove,CapabilityRemove,FeatureDisable,StoreInstall'
        $legacy = @($r.Tweaks | Where-Object { $_.Section -eq 'Apps' -and $_.Category -eq 'Remove' -and -not $_.Group } | ForEach-Object { $_.Id } | Sort-Object)
        $legacy -join ',' | Should Be 'remove-brlapi,remove-edge,remove-gameinput,remove-onedrive,remove-remote-desktop-connection,remove-snipping-tool-legacy,remove-update-for-x64,remove-update-health-tools,remove-webview2'
    }

    It 'removes Edge and WebView2 separately: the AkariOS pick takes Edge, WebView2 only when checked by hand' {
        $edge = $r.Tweaks | Where-Object { $_.Id -eq 'remove-edge' }
        $wv = $r.Tweaks | Where-Object { $_.Id -eq 'remove-webview2' }
        $edge.Keep | Should Be $false
        $wv.Keep | Should Be $true
        $wv.Confirm | Should Match 'WebView2'
    }

    It 'builds a feature found on the PC as an Entry: named from the catalogue, kept by FR33THY''s keep-list, restart needed' {
        $cap = Resolve-AkariEntry $r.Groups 'capability/App.StepsRecorder~~~~0.0.1.0'
        $cap.Name | Should Be 'Steps Recorder'
        $cap.Keep | Should Be $false
        $cap.Reboot | Should Be $true
        "$($cap.Apply)" | Should Be "Remove-AkariCapability 'App.StepsRecorder~~~~0.0.1.0'"
        "$($cap.Detect)" | Should Be "-not (Test-AkariCapabilityInstalled 'App.StepsRecorder~~~~0.0.1.0')"
        $vbs = Resolve-AkariEntry $r.Groups 'capability/VBSCRIPT~~~~'
        $vbs.Keep | Should Be $true
        $vbs.Risk | Should Be 'Advanced'
        $f = Resolve-AkariEntry $r.Groups 'feature/WorkFolders-Client'
        $f.Name | Should Be 'Work Folders Client'
        "$($f.Apply)" | Should Be "Disable-AkariFeature 'WorkFolders-Client'"
        (Resolve-AkariEntry $r.Groups 'feature/Windows-Defender-Default-Definitions').Keep | Should Be $true
        (Resolve-AkariEntry $r.Groups 'feature/Some-Unknown-Feature').Risk | Should Be 'Caution'
    }

    It 'does not load the feature catalogues as Tweaks of their own' {
        @($r.Tweaks | Where-Object { $_.Group -in 'capability', 'feature' }).Count | Should Be 0
    }
}
