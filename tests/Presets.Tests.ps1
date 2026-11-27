$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

Describe 'Presets: reading, resolving, saving' {
    $AkariPresetDir = "$TestDrive\presets"
    $AkariLastUsedPath = "$TestDrive\lastused.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'Presets') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $tw = @(
        ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Registry = @{ Path = 'HKCU:\x'; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 } } 'x' $false
        ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Kind = 'Choice'; Recommended = 38; Default = 2; Registry = @{ Path = 'HKCU:\x'; Name = 'C'; Type = 'DWord' }; Choices = @(@{ Value = 38 }, @{ Value = 40 }) } 'x' $false
        ConvertTo-AkariTweak @{ Id = 'act'; Name = 'Act'; Kind = 'Action'; Apply = { } } 'x' $false
        ConvertTo-AkariTweak @{ Id = 'appx/One'; Name = 'One'; Kind = 'Action'; Group = 'appx'; Apply = { } } 'x' $false
        ConvertTo-AkariTweak @{ Id = 'appx/Kept'; Name = 'Kept'; Kind = 'Action'; Group = 'appx'; Keep = $true; Apply = { } } 'x' $false
    )
    $file = "$TestDrive\builtin\Test.json"
    New-Item (Split-Path $file) -ItemType Directory -Force | Out-Null
    Set-Content $file '{ "Name": "Test", "Description": "D", "Tweaks": [ "appx/*", "tog", { "ch": 40 }, { "act": "Default" }, "appx/One", "nope", "zz/*" ] }'

    It 'reads entries: ids, Choice values, Defaults, wildcards' {
        $p = Read-AkariPreset $file $true
        $p.Name | Should Be 'Test'
        ($p.Entries | ForEach-Object { $_.Id }) -join ',' | Should Be 'appx/*,tog,ch,act,appx/One,nope,zz/*'
        $p.Entries[2].Value | Should Be 40
    }

    It 'resolves to plan items: wildcard = non-keep Entries, a Choice value, a Default = Revert, each once; unknown listed' {
        $r = Resolve-AkariPreset (Read-AkariPreset $file) $tw
        ($r.Items | ForEach-Object { "$($_.Id):$($_.Mode)$(if ($_.ContainsKey('Value')) { "=$($_.Value)" })" }) -join ' ' | Should Be 'appx/One:Apply tog:Apply ch:Apply=40 act:Revert'
        # a wildcard that matches nothing is not unknown: nothing of that Group is on this PC
        $r.Unknown -join ',' | Should Be 'nope'
    }

    It 'gives a Choice at its Recommended value no Value' {
        Set-Content "$TestDrive\rec.json" '{ "Tweaks": [ { "ch": 38 } ] }'
        (Resolve-AkariPreset (Read-AkariPreset "$TestDrive\rec.json") $tw).Items[0].ContainsKey('Value') | Should Be $false
    }

    It 'reverts in reverse order, every item Revert, no values' {
        $r = Resolve-AkariPreset (Read-AkariPreset $file) $tw -Revert
        ($r.Items | ForEach-Object { "$($_.Id):$($_.Mode)" }) -join ' ' | Should Be 'act:Revert ch:Revert tog:Revert appx/One:Revert'
        @($r.Items | Where-Object { $_.ContainsKey('Value') }).Count | Should Be 0
    }

    It 'saves a Selection and reads it back to the same plan (Apply, Choice value, Revert)' {
        $items = @(@{ Id = 'tog'; Mode = 'Apply' }, @{ Id = 'ch'; Mode = 'Apply'; Value = 40 }, @{ Id = 'act'; Mode = 'Revert' })
        $path = Save-AkariPreset 'My PC: gaming' $items 'mine'
        $path | Should Be "$TestDrive\presets\My PC_ gaming.json"
        $back = Resolve-AkariPreset (Read-AkariPreset $path) $tw
        ($back.Items | ForEach-Object { "$($_.Id):$($_.Mode)$(if ($_.ContainsKey('Value')) { "=$($_.Value)" })" }) -join ' ' | Should Be 'tog:Apply ch:Apply=40 act:Revert'
    }

    It 'lists built-in presets first, then the user''s, and finds them by name or by file' {
        (Get-AkariPresets "$TestDrive\builtin" | ForEach-Object { "$($_.Name)/$($_.Builtin)" }) -join ',' | Should Be 'Test/True,My PC: gaming/False'
        (Find-AkariPreset 'my pc: GAMING' "$TestDrive\builtin").Name | Should Be 'My PC: gaming'
        (Find-AkariPreset $file "$TestDrive\builtin").Name | Should Be 'Test'
        Find-AkariPreset 'none' "$TestDrive\builtin" | Should BeNullOrEmpty
    }

    It 'keeps Last used apart from the user''s presets' {
        Get-AkariLastUsed | Should BeNullOrEmpty
        Save-AkariLastUsed @(@{ Id = 'tog'; Mode = 'Apply' })
        (Get-AkariLastUsed).Name | Should Be 'Last used'
        @(Get-AkariPresets "$TestDrive\builtin" | Where-Object { $_.Name -eq 'Last used' }).Count | Should Be 0
    }
}

Describe 'Presets\AkariOS.json' {
    $AkariPresetDir = "$TestDrive\none"
    foreach ($f in 'Log', 'Registry', 'Loader', 'Presets') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $loaded = Get-AkariTweaks (Join-Path $Root 'Tweaks')
    $p = Find-AkariPreset 'AkariOS' (Join-Path $Root 'Presets')
    $ids = @($p.Entries | ForEach-Object { $_.Id })

    It 'is built in and every id is a Tweak' {
        $p.Builtin | Should Be $true
        (Resolve-AkariPreset $p $loaded.Tweaks).Unknown -join ',' | Should Be ''
    }

    It 'is exactly the debloat, the non-keep legacy app removals, One-click''s own steps and every Tweak marked AkariOS' {
        $want = @('appx/*', 'capability/*', 'feature/*') +
            # One-click's own steps: Section OneClick, and the two that moved to Tools keeping their oneclick- id
            @($loaded.Tweaks | Where-Object { $_.Section -eq 'OneClick' -or $_.Id -like 'oneclick-*' } | ForEach-Object { $_.Id }) +
            @($loaded.Tweaks | Where-Object { -not $_.Group -and $_.Section -eq 'Apps' -and $_.Category -eq 'Remove' -and -not $_.Keep } | ForEach-Object { $_.Id }) +
            @($loaded.Tweaks | Where-Object { -not $_.Group -and $_.AkariOS } | ForEach-Object { $_.Id })
        @($want | Where-Object { $_ -notin $ids }) -join ',' | Should Be ''
        @($ids | Where-Object { $_ -notin $want }) -join ',' | Should Be ''
    }
}

Describe 'One-click''s picks (the native OneClickPicks)' {
    $AkariPresetDir = "$TestDrive\none"
    foreach ($f in 'Log', 'Registry', 'Loader', 'Presets') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $loaded = Get-AkariTweaks (Join-Path $Root 'Tweaks')
    $p = Find-AkariPreset 'AkariOS' (Join-Path $Root 'Presets')
    $ids = { param($x) @($x.Entries | ForEach-Object { $_.Id }) }
    $all = & $ids $p
    $at = [array]::IndexOf($all, 'install-helium')

    It 'lists the browser installs: the preset''s Helium first, then by name, Edge among them' {
        $b = @(Get-AkariOneClickBrowsers $loaded.Tweaks)
        $b[0].Id | Should Be 'install-helium'
        @($b | Where-Object { $_.AppType -ne 'Browsers' -or $_.Kind -ne 'Action' }).Count | Should Be 0
        @($b | ForEach-Object { $_.Id }) -contains 'install-microsoft-edge' | Should Be $true
        $rest = @($b | Select-Object -Skip 1 | ForEach-Object { $_.Name })
        ($rest -join ',') | Should Be (@($rest | Sort-Object) -join ',')
    }

    It 'leaves the preset as it is with Helium on a desktop' {
        $at | Should BeGreaterThan -1
        (& $ids (Get-AkariOneClickPreset $p 'install-helium' 'Desktop')) -join ',' | Should Be ($all -join ',')
    }

    It 'puts the picked browser in Helium''s place, in its phase, and leaves the preset itself alone' {
        $q = Get-AkariOneClickPreset $p 'install-brave' 'Desktop'
        (& $ids $q)[$at] | Should Be 'install-brave'
        $q.Entries[$at].Phase | Should Be $p.Entries[$at].Phase
        (& $ids $q) -contains 'install-helium' | Should Be $false
        $p.Entries[$at].Id | Should Be 'install-helium'
        @($q.Phases).Count | Should Be @($p.Phases).Count
    }

    It 'keeps Edge when Edge is picked, installs no browser for none, and leaves the power plan out on a laptop' {
        $all -contains 'remove-edge' | Should Be $true
        $all -contains 'power-ultimate-plan' | Should Be $true
        $edge = & $ids (Get-AkariOneClickPreset $p 'install-microsoft-edge' 'Desktop')
        "$($edge -contains 'remove-edge')|$($edge[$at])" | Should Be 'False|install-microsoft-edge'
        $none = & $ids (Get-AkariOneClickPreset $p '' 'Desktop')
        "$($none -contains 'install-helium')|$($none.Count)|$($none -contains 'remove-edge')" | Should Be "False|$($all.Count - 1)|True"
        $laptop = & $ids (Get-AkariOneClickPreset $p 'install-helium' 'Laptop')
        "$($laptop -contains 'power-ultimate-plan')|$($laptop.Count)" | Should Be "False|$($all.Count - 1)"
    }

    It 'adds a browser the preset lacks first, and keeps one it already has once, where it was' {
        $s = @{ Name = 's'; Entries = @(@{ Id = 'a'; Phase = 0 }, @{ Id = 'install-brave'; Phase = 1 }, @{ Id = 'install-helium'; Phase = 1 }) }
        (& $ids (Get-AkariOneClickPreset $s 'install-brave' 'Desktop')) -join ',' | Should Be 'a,install-brave'
        $q = Get-AkariOneClickPreset @{ Name = 'x'; Entries = @(@{ Id = 'a'; Phase = 1 }) } 'install-x' 'Desktop'
        "$((& $ids $q) -join ',')|$($q.Entries[0].Phase)|$($q.Entries[0].HasValue)" | Should Be 'install-x,a|0|False'
    }

    It 'says what the picks leave out, for akari.log' {
        (Get-AkariOneClickNotes 'install-brave' 'Desktop') -join '/' | Should Be 'One-click: browser install-brave.'
        (Get-AkariOneClickNotes '' 'Laptop') -join '/' | Should Be 'One-click: no browser installed./One-click: this PC is a laptop, the Ultimate Performance power plan is left out.'
        (Get-AkariOneClickNotes 'install-microsoft-edge' 'Desktop') -join '/' | Should Be 'One-click: browser install-microsoft-edge./One-click: Microsoft Edge kept (remove-edge left out).'
    }
}

Describe 'Akari.ps1 -Preset' {
    It 'refuses an unknown preset before anything runs (exit 2)' {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Akari.ps1') -Preset 'zz-no-such-preset' 2>&1 | ForEach-Object { "$_" }
        $LASTEXITCODE | Should Be 2
        ($out -join "`n") | Should Match "No preset 'zz-no-such-preset'|elevated"
    }
}

Describe 'Quick select (in memory, no window)' {
    $probe = "$TestDrive\quick.ps1"
    Set-Content $probe -Value @'
param($Root, $Key)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariStatePath = "$env:TEMP\akari-quick-test-state.json"
$AkariPresetDir = "$env:TEMP\akari-quick-test-presets"
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'Presets') { . "$Root\Core\$f.ps1" }
$LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
New-Item $Key -Force | Out-Null; New-ItemProperty $Key -Name 'O' -Value 0 -PropertyType DWord | Out-Null
$fx = Get-AkariTweaks "$Root\..\tests\Fixtures\Tweaks"
$script:Groups = @($fx.Groups)
$script:Tweaks = @(
    ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'T'; Type = 'DWord'; Value = 0; Default = $null } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'opt'; Name = 'Opt'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'O'; Type = 'DWord'; Value = 0; Default = $null } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Description = 'D'; Section = 'Advanced'; Category = 'Tuning'; Kind = 'Choice'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'C'; Type = 'DWord' }; Recommended = 0x26; Default = 2; Editable = $true
        Choices = @(@{ Value = 0x26; Label = 'A' }, @{ Value = 0x28; Label = 'B' }) } 'x' $false
    # Optimize > Advanced only: no row on the Tweaks step
    ConvertTo-AkariTweak @{ Id = 'adv'; Name = 'Adv'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Guided = $false
        Registry = @{ Path = $Key; Name = 'H'; Type = 'DWord'; Value = 1; Default = $null } } 'x' $false
) + @($fx.Tweaks | Where-Object { $_.Group })
$AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
$AkariLogFile = "$env:TEMP\akari-quick-test\akari.log"
$env:AKARI_MOTION = 'off'; . "$Root\UI\Motion.ps1"; . "$Root\UI\Aurora.ps1"
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps', 'Pages') { . "$Root\UI\$f.ps1" }
. "$Root\..\tests\ShellStub.ps1"
function Get-AkariAppxPackages { @() }
function Get-AkariAppxInstalled { @('Akari.Test.One', 'Akari.Test.Two') }; function Start-AkariFeatureRead { }; function Add-Log($m) { }
$res = [Windows.Controls.StackPanel]::new()
. "$Root\UI\Motion.ps1"
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Controls.xaml"))
$res.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Icons.xaml"))
$script:Mode = 'Guided'; $script:Step = 1
[void](Get-AkariTweaksView)
# a pick of the user's that the preset must replace
$script:TweakRows['ch'].Control.SelectedIndex = 2; Set-AkariChoiceTarget 'ch' 0x28
$p = @{ Name = 'P'; Entries = @(@{ Id = 'tog'; HasValue = $false }, @{ Id = 'opt'; Value = 'Default'; HasValue = $true }, @{ Id = 'good-group/*'; HasValue = $false }, @{ Id = 'adv'; HasValue = $false }) }
Set-AkariQuickSelect $p
"sel=$((Get-AkariPlanItems $script:Sel | ForEach-Object { "$($_.Id):$($_.Mode)" }) -join ' ')"
"hidden=$((Get-AkariReviewItems $script:Sel | Where-Object { $_.Hidden } | ForEach-Object { $_.Id }) -join ',')"
"togChecked=$($script:TweakRows['tog'].Control.IsChecked)"; "optChecked=$($script:TweakRows['opt'].Control.IsChecked)"; "chIndex=$($script:TweakRows['ch'].Control.SelectedIndex)"
"appOne=$($script:AppRows['good-group/Akari.Test.One'].Control.IsChecked)"; "appTwo=$($script:AppRows['good-group/Akari.Test.Two'].Control.IsChecked)"
# Clear selection drops the hidden change too
Reset-AkariTweakRows
"afterClear=$((Get-AkariPlanItems $script:Sel | ForEach-Object { $_.Id }) -join ' ')"

# in the window the States and apps are read in the background: the grid says "Reading..." and a Quick select waits for
# both reads (the jobs are recorded, never run; their results are handed over by hand)
$AkariReadInline = $false
Clear-AkariSteps; $script:Appx = $null
$script:Jobs = @()
function Start-AkariJob($Code, $Queue, $CoreDir, $Shared) { $j = @{ Code = $Code; Shared = $Shared; Handle = [pscustomobject]@{ IsCompleted = $false } }; $script:Jobs += , $j; $j }
"waitView=$((Get-AkariTweaksView).GetType().Name)|$($null -eq $script:TweaksView)"
Set-AkariQuickSelect $p
"waitPick=$($script:QuickPending.Name)|$($script:Sel.Count)|$($script:Jobs.Count)"
$sj = $script:Jobs | Where-Object { $_.Shared.Items } | Select-Object -First 1
$aj = $script:Jobs | Where-Object { -not $_.Shared.Items } | Select-Object -First 1
"stateItems=$(($sj.Shared.Items | ForEach-Object { $_.Id }) -join ',')"
$sj.Shared.States['tog'] = @{ State = 'Default'; Current = $null }; $sj.Shared.States['opt'] = @{ State = 'Optimized'; Current = $null }
Complete-AkariTweakStates $sj
"afterStates=$($null -ne $script:QuickPending)|$($script:Sel.Count)|$($script:TweakStates['ch'].State)"
$aj.Shared.Result = @{ Names = @('Akari.Test.One', 'Akari.Test.Two'); Installed = @('Akari.Test.One', 'Akari.Test.Two'); Logos = @{} }
Complete-AkariAppxRead $aj
"bgSel=$((Get-AkariPlanItems $script:Sel | ForEach-Object { "$($_.Id):$($_.Mode)" }) -join ' ')"
"bgPending=$($null -eq $script:QuickPending)|$($script:TweakRows['opt'].State)"
# a read that ends after the steps were cleared (a flow switch, Done) is dropped
$script:Jobs = @()
Clear-AkariSteps
[void](Get-AkariTweaksView)
$old = $script:Jobs | Where-Object { $_.Shared.Items } | Select-Object -First 1
Clear-AkariSteps
Complete-AkariTweakStates $old
"stale=$($null -eq $script:TweakStates)|$($null -eq $script:TweakStatesJob)"
'@
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $out = @{}
    try {
        & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Key $k 2>&1 | ForEach-Object {
            $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }

    It 'runs without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'replaces the Selection with the preset: Apply, Revert of an Optimized row, the wildcard''s non-keep apps' {
        $out.sel | Should Be 'good-group/Akari.Test.One:Apply tog:Apply opt:Revert adv:Apply'
        $out.togChecked | Should Be 'True'
        $out.optChecked | Should Be 'False'
        $out.chIndex | Should Be '0'
        $out.appOne | Should Be 'True'
        $out.appTwo | Should Be 'False'
    }
    It 'selects a Tweak Guided doesn''t show, marked for its own Review heading; Clear selection drops it' {
        $out.hidden | Should Be 'adv'
        $out.afterClear | Should Be 'good-group/Akari.Test.One'
    }
    It 'reads the States and apps in the background: the grid says Reading until they are in' {
        $out.waitView | Should Be 'StackPanel|True'
        # Actions have no State to read
        $out.stateItems | Should Be 'tog,opt,ch'
    }
    It 'keeps a Quick select waiting for both reads, then picks it as before' {
        $out.waitPick | Should Be 'P|0|2'
        $out.afterStates | Should Be 'True|0|Unknown'
        $out.bgSel | Should Be 'good-group/Akari.Test.One:Apply tog:Apply opt:Revert adv:Apply'
        $out.bgPending | Should Be 'True|Optimized'
    }
    It 'drops a read that ends after the steps were cleared' { $out.stale | Should Be 'True|True' }
}

Describe 'Export settings' {
    $AkariPresetDir = "$TestDrive\presets"
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'Presets') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $k = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    New-Item $k -Force | Out-Null
    $T = { param($h) ConvertTo-AkariTweak $h 'x' $false }
    $tw = @(
        & $T @{ Id = 'on'; Name = 'On'; Section = 'Optimize'; Category = 'G'; Registry = @{ Path = $k; Name = 'On'; Type = 'DWord'; Value = 1; Default = $null } }
        & $T @{ Id = 'off'; Name = 'Off'; Section = 'Optimize'; Category = 'G'; Registry = @{ Path = $k; Name = 'Off'; Type = 'DWord'; Value = 1; Default = $null } }
        & $T @{ Id = 'rec'; Name = 'Rec'; Section = 'Advanced'; Category = 'T'; Kind = 'Choice'; Recommended = 38; Default = 2; Registry = @{ Path = $k; Name = 'Rec'; Type = 'DWord' }; Choices = @(@{ Value = 38 }, @{ Value = 40 }) }
        & $T @{ Id = 'other'; Name = 'Other'; Section = 'Advanced'; Category = 'T'; Kind = 'Choice'; Recommended = 38; Default = 2; Registry = @{ Path = $k; Name = 'Other'; Type = 'DWord' }; Choices = @(@{ Value = 38 }, @{ Value = 40 }) }
        & $T @{ Id = 'def'; Name = 'Def'; Section = 'Advanced'; Category = 'T'; Kind = 'Choice'; Recommended = 38; Default = 2; Registry = @{ Path = $k; Name = 'Def'; Type = 'DWord' }; Choices = @(@{ Value = 38 }, @{ Value = 40 }) }
        & $T @{ Id = 'act'; Name = 'Act'; Section = 'Tools'; Category = 'C'; Kind = 'Action'; Apply = { } }
        & $T @{ Id = 'one'; Name = 'One'; Section = 'OneClick'; Category = 'C'; Registry = @{ Path = $k; Name = 'One'; Type = 'DWord'; Value = 1; Default = $null } }
    )
    foreach ($n in @(@('On', 1), @('Rec', 38), @('Other', 40), @('Def', 2), @('One', 1))) { New-ItemProperty $k -Name $n[0] -Value $n[1] -PropertyType DWord | Out-Null }

    try {
        It 'turns what a PC has into plan items: Optimized Toggles, Choices off their Default (a value only when not Recommended)' {
            $rows = @(@{ Tweak = $tw[0]; State = 'Optimized' }, @{ Tweak = $tw[1]; State = 'Custom' }, @{ Tweak = $tw[2]; Value = 38 },
                @{ Tweak = $tw[3]; Value = 40 }, @{ Tweak = $tw[4]; Value = 2 }, @{ Tweak = $tw[3]; Value = 99 }, @{ Tweak = $tw[2]; Value = $null })
            (@(ConvertTo-AkariExportItems $rows) | ForEach-Object { "$($_.Id)$(if ($_.ContainsKey('Value')) { "=$($_.Value)" })" }) -join ' ' | Should Be 'on rec other=40'
        }
        It 'writes this PC''s settings as a preset an import reads back, with an Exported block' {
            $r = Export-AkariSettings $tw "$TestDrive\out\settings.json" '9.9.9'
            $r.Count | Should Be 3
            $p = Read-AkariPreset $r.Path
            ($p.Entries | ForEach-Object { "$($_.Id)$(if ($_.HasValue) { "=$($_.Value)" })" }) -join ' ' | Should Be 'on rec other=40'
            $j = Get-Content $r.Path -Raw | ConvertFrom-Json
            $j.Exported.AkariVersion | Should Be '9.9.9'
            $j.Exported.Computer | Should Be $env:COMPUTERNAME
            $j.Name | Should Be "Exported from $env:COMPUTERNAME"
        }
    } finally { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
}
