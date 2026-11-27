$Root = Join-Path (Split-Path $PSScriptRoot) 'src'

# The Aurora banner (ADR 0011, plan docs/plans/2026-11-26-aurora-powershell.md): UI\Aurora.ps1's pure helpers, the
# theme keys, and the backdrop and bloom built in a child STA PowerShell (no window is shown).

Describe 'Aurora (UI\Aurora.ps1): the page''s light' {
    . "$Root\UI\Aurora.ps1"

    It 'is 460 px tall, 640 on Home' {
        "$(Get-AkariAuroraHeight $false) $(Get-AkariAuroraHeight $true)" | Should Be '460 640'
    }

    It 'places the three glows from the page''s width (the native app''s sizes and drift)' {
        $g = @(Get-AkariAuroraGlows 1000 $false)
        $g.Count | Should Be 3
        ($g | ForEach-Object { "$($_.Right) $($_.Width) $($_.Height) $($_.Margin -join ',') $($_.Opacity)" }) -join '|' |
            Should Be 'False 620 280 -80,-160,0,0 1|True 560 240 0,-120,-60,0 1|False 420 140 340,60,0,0 0.7'
        ($g | ForEach-Object { "$([Math]::Round($_.DriftX, 2)) $($_.DriftY) $($_.ScaleFrom) $($_.ScaleTo) $($_.Seconds)" }) -join '|' |
            Should Be '49.6 30 1 1.15 16|-56 40 1.1 0.95 19|50.4 -30 1 1 13'
        (@(Get-AkariAuroraGlows 1000 $true) | ForEach-Object { $_.Height }) -join ',' | Should Be '460,420,320'
    }

    It 'puts the ribbons in a box 64 % of the page wide, 230 px tall (340 on Home), faded from 40 %' {
        $r = Get-AkariAuroraRibbonBox 1000 $false
        "$($r.Width) $($r.Height) $($r.FadeFrom) $($r.SwayX) $($r.SwayY)" | Should Be '640 230 0.4 24 10'
        (Get-AkariAuroraRibbonBox 1000 $true).Height | Should Be 340
    }

    It 'dims the layers more in the light theme' {
        $d = Get-AkariAuroraOpacity 'Dark'; $l = Get-AkariAuroraOpacity 'Light'
        "$($d.Glows) $($d.Ribbons) $($l.Glows) $($l.Ribbons)" | Should Be '0.55 0.8 0.32 0.55'
    }

    It 'gives each page its palette' {
        $cases = @(
            @('Home', '', '', 'Home'), @('Install AkariOS', '', '', 'Install'), @('Optimize', '', '', 'Optimize'),
            @('Catalogue:Optimize/Gaming', '', '', 'Optimize'), @('Search', 'dns', '', 'Optimize'), @('Downloads', '', 'External', 'Downloads'),
            @('Downloads', '', 'Windows', 'Remove'), @('Install USB', '', '', 'Usb'), @('ISO Builder', '', '', 'Iso'), @('Settings', '', '', 'Settings'),
            @('Check', '', '', 'Optimize'))
        foreach ($c in $cases) { "$($c[0]) $(Get-AkariPagePalette $c[0] $c[1] $c[2])" | Should Be "$($c[0]) $($c[3])" }
        foreach ($c in $cases) { $AkariAuroraPalettes -contains $c[3] | Should Be $true }
    }

    It 'clips the light to the content layer''s rounded top left corner (ClipToBounds ignores CornerRadius)' {
        Add-Type -AssemblyName PresentationCore
        $c = New-AkariCornerClip 1000 460
        "$($c.Bounds) $($c.FillContains([Windows.Point]::new(0.5, 0.5))) $($c.FillContains([Windows.Point]::new(6, 6))) $($c.FillContains([Windows.Point]::new(999, 0.5))) $($c.FillContains([Windows.Point]::new(0.5, 459)))" |
            Should Be '0,0,1000,460 False True True True'
    }

    It 'draws the design''s bloom: a corner glow and three ribbons that parse as geometry' {
        $a = Get-AkariRibbonArt
        "$($a.Width)x$($a.Height) $($a.Ribbons.Count) $(($a.Ribbons | ForEach-Object { "$($_.Opacity)" }) -join '/')" | Should Be '560x280 3 1/0.75/0.6'
        Add-Type -AssemblyName PresentationCore
        foreach ($r in $a.Ribbons) { [Windows.Media.Geometry]::Parse($r.Data).Bounds.Right | Should Be 560 }
    }
}

Describe 'Aurora colours (UI\Theme.Dark.xaml, UI\Theme.Light.xaml)' {
    . "$Root\UI\Aurora.ps1"
    $read = { param($f) $x = ([xml](Get-Content "$Root\UI\Theme.$f.xaml" -Raw)).ResourceDictionary; $h = @{}; foreach ($c in @($x.Color)) { $h[$c.Key] = $c.'#text' }; $h }
    $dark = & $read 'Dark'; $light = & $read 'Light'

    It 'has every palette''s five colours in both themes, the same in each' {
        $miss = foreach ($p in $AkariAuroraPalettes) {
            foreach ($k in 'A', 'B', 'C', 'Ribbon', 'RibbonLight') {
                $n = "Aurora$p$k"
                if (-not $dark[$n] -or $dark[$n] -ne $light[$n]) { $n }
            }
        }
        @($miss) -join ', ' | Should Be ''
        "$($dark.AuroraHomeA) $($dark.AuroraRemoveA) $($dark.AuroraIsoRibbonLight) $($dark.AuroraWhite)" | Should Be '#E3263F #0F9D8A #E59CF0 #FFFFFF'
    }

    It 'has the glass in both themes: a translucent fill, a stroke whose top pixel is brighter' {
        foreach ($f in 'Dark', 'Light') {
            $x = ([xml](Get-Content "$Root\UI\Theme.$f.xaml" -Raw)).ResourceDictionary
            @($x.SolidColorBrush | Where-Object { $_.Key -eq 'Glass' }).Count | Should Be 1
            $s = @($x.LinearGradientBrush | Where-Object { $_.Key -eq 'GlassStroke' })[0]
            "$f $($s.MappingMode) $($s.EndPoint) $(@($s.GradientStop).Count)" | Should Be "$f Absolute 0,2 3"
        }
    }

    It 'keeps colour literals out of Aurora.ps1 (the theme''s colours only)' {
        @(Select-String -Path "$Root\UI\Aurora.ps1" -Pattern '#[0-9A-Fa-f]{6,8}\b|FromRgb|FromArgb\(\d') | ForEach-Object { $_.LineNumber } | Should BeNullOrEmpty
    }

    It 'starts every animation in Motion.ps1' {
        @(Select-String -Path "$Root\UI\Aurora.ps1" -Pattern '\.BeginAnimation\(|Storyboard') | ForEach-Object { $_.LineNumber } | Should BeNullOrEmpty
    }
}

Describe 'Aurora backdrop and bloom (WPF)' {
    $probe = "$TestDrive\aurora.ps1"
    Set-Content $probe -Value @'
param($Root, $Motion)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$env:AKARI_MOTION = $Motion; . "$Root\UI\Motion.ps1"; . "$Root\UI\Aurora.ps1"
$window = [Windows.Controls.Grid]::new()
$window.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Theme.Dark.xaml"))
$script:Theme = 'Dark'
$g = [Windows.Controls.Grid]::new(); [void]$window.Children.Add($g)
New-AkariAurora $g
Set-AkariAuroraPalette 'Optimize' $false 'Optimize'
Update-AkariAuroraSize 1000
$a = $script:AuroraState
$c = $a.Glows.Children[0].Fill.GradientStops
"built=$($g.Children.Count)|$($g.IsHitTestVisible)|$($g.Height)|$($a.Palette)"
"glow=$($c[0].Color)|$($c[1].Color)|$($a.Glows.Children[0].Width)|$($a.Glows.Opacity)|$($a.Box.Opacity)"
"box=$($a.Box.Width)|$($a.Box.Height)|$($a.Box.ClipToBounds)|$($a.Box.OpacityMask.GradientStops[1].Offset)|$($a.Art.Margin)"
"art=$($a.Art.Fill.Stretch)|$($a.Art.Fill.AlignmentX)|$($a.Art.Fill.AlignmentY)|$($a.Art.Fill.Drawing.Children.Count)"
"moving=$($a.Moving)|$($a.Glows.Children[0].RenderTransform.Children[-1].HasAnimatedProperties)"
$script:Theme = 'Light'; Update-AkariAuroraTheme; "light=$($a.Glows.Opacity)|$($a.Box.Opacity)"
Set-AkariAuroraPalette 'Home' $true 'Home'; "home=$($g.Height)|$($a.Box.Height)|$($a.Glows.Children[0].Fill.GradientStops[0].Color)"
Set-AkariAuroraPalette 'Nope' $false 'X'; "unknown=$($a.Palette)"
$b = New-AkariBloom 'Install'
"bloom=$($b.Width)|$($b.Height)|$($b.Opacity)|$($b.IsHitTestVisible)|$($b.HorizontalAlignment)|$($b.VerticalAlignment)|$($b.OpacityMask.GradientStops[1].Offset)|$($null -ne $b.Clip)"
'@
    foreach ($m in 'on', 'off') {
        $out = @{}
        & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Motion $m 2>&1 | ForEach-Object {
            $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
        }
        It "builds the backdrop with motion $m" {
            $out['error'] | Should BeNullOrEmpty
            $out.built | Should Be '2|False|460|Optimize'
            $out.glow | Should Be '#FFE3263F|#00E3263F|620|0.55|0.8'
            $out.box | Should Be '640|230|True|0.4|0,-10,-24,0'
            $out.art | Should Be 'UniformToFill|Right|Top|4'
            $out.light | Should Be '0.32|0.55'
            $out.home | Should Be '640|340|#FFE3263F'
            $out.unknown | Should Be 'Home'
            $out.bloom | Should Be '360|180|0.7|False|Right|Top|0.2|True'
        }
        It "moves only with motion on ($m)" {
            # software rendering (render tier 0) keeps it still too: the test host may have no GPU
            $tier = & powershell -NoProfile -STA -Command 'Add-Type -AssemblyName PresentationCore; [Windows.Media.RenderCapability]::Tier -shr 16'
            $want = if ($m -eq 'on' -and [int]"$tier" -gt 0) { 'True|True' } else { 'False|False' }
            $out.moving | Should Be $want
        }
    }
}
