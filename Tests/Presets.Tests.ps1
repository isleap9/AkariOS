$Root = Split-Path $PSScriptRoot
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
            @($loaded.Tweaks | Where-Object { $_.Section -eq 'OneClick' } | ForEach-Object { $_.Id }) +
            @($loaded.Tweaks | Where-Object { -not $_.Group -and $_.Section -eq 'Apps' -and $_.Category -eq 'Remove' -and -not $_.Keep } | ForEach-Object { $_.Id }) +
            @($loaded.Tweaks | Where-Object { -not $_.Group -and $_.AkariOS } | ForEach-Object { $_.Id })
        @($want | Where-Object { $_ -notin $ids }) -join ',' | Should Be ''
        @($ids | Where-Object { $_ -notin $want }) -join ',' | Should Be ''
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
$fx = Get-AkariTweaks "$Root\Tests\Fixtures\Tweaks"
$script:Groups = @($fx.Groups)
$script:Tweaks = @(
    ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'T'; Type = 'DWord'; Value = 0; Default = $null } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'opt'; Name = 'Opt'; Description = 'D'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'O'; Type = 'DWord'; Value = 0; Default = $null } } 'x' $false
    ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Description = 'D'; Section = 'Advanced'; Category = 'Tuning'; Kind = 'Choice'; Risk = 'Safe'
        Registry = @{ Path = $Key; Name = 'C'; Type = 'DWord' }; Recommended = 0x26; Default = 2; Editable = $true
        Choices = @(@{ Value = 0x26; Label = 'A' }, @{ Value = 0x28; Label = 'B' }) } 'x' $false
) + @($fx.Tweaks | Where-Object { $_.Group })
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps') { . "$Root\UI\$f.ps1" }
function Get-AkariAppxInstalled { @('Akari.Test.One', 'Akari.Test.Two') }; function Start-AkariFeatureRead { }; function Add-Log($m) { }
$res = [Windows.Controls.StackPanel]::new()
$res.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$res.Resources['Icons'] = [Windows.Media.FontFamily]::new('Segoe MDL2 Assets')
$StepDots = [Windows.Controls.StackPanel]::new(); $StepBody = [Windows.Controls.StackPanel]::new()
$StepBack = [Windows.Controls.Button]::new(); $StepNext = [Windows.Controls.Button]::new(); $Search = [Windows.Controls.TextBox]::new()
$StepFooter = [Windows.Controls.Border]::new()
$script:Mode = 'Guided'; $script:Step = 1
[void](Get-AkariTweaksView)
# a pick of the user's that the preset must replace
$script:TweakRows['ch'].Control.SelectedIndex = 2; Set-AkariChoiceTarget 'ch' 0x28
$p = @{ Name = 'P'; Entries = @(@{ Id = 'tog'; HasValue = $false }, @{ Id = 'opt'; Value = 'Default'; HasValue = $true }, @{ Id = 'good-group/*'; HasValue = $false }) }
Set-AkariQuickSelect $p
"sel=$((Get-AkariPlanItems $script:Sel | ForEach-Object { "$($_.Id):$($_.Mode)" }) -join ' ')"
"togChecked=$($script:TweakRows['tog'].Control.IsChecked)"; "optChecked=$($script:TweakRows['opt'].Control.IsChecked)"; "chIndex=$($script:TweakRows['ch'].Control.SelectedIndex)"
"appOne=$($script:AppRows['good-group/Akari.Test.One'].Control.IsChecked)"; "appTwo=$($script:AppRows['good-group/Akari.Test.Two'].Control.IsChecked)"
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
        $out.sel | Should Be 'good-group/Akari.Test.One:Apply tog:Apply opt:Revert'
        $out.togChecked | Should Be 'True'
        $out.optChecked | Should Be 'False'
        $out.chIndex | Should Be '0'
        $out.appOne | Should Be 'True'
        $out.appTwo | Should Be 'False'
    }
}
