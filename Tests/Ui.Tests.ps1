$Root = Split-Path $PSScriptRoot

# Parses XAML in a child STA PowerShell (WPF needs STA). No window is created or shown.
function Test-XamlInChild([string]$Script) {
    $out = & powershell -NoProfile -STA -ExecutionPolicy Bypass -Command $Script 2>&1
    @($out | ForEach-Object { "$_" }) -join "`n"
}

Describe 'UI files' {
    It 'UI scripts and Akari.ps1 have no parse errors' {
        foreach ($f in @(Get-ChildItem "$Root\UI\*.ps1") + @(Get-Item "$Root\Akari.ps1")) {
            $errs = $null
            [void][Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
            "$($f.Name): $($errs.Count)" | Should Be "$($f.Name): 0"
        }
    }

    It 'MainWindow.xaml parses' {
        $s = "Add-Type -AssemblyName PresentationFramework; [void][Windows.Markup.XamlReader]::Parse((Get-Content '$Root\UI\MainWindow.xaml' -Raw)); 'ok'"
        Test-XamlInChild $s | Should Be 'ok'
    }

    It 'has no tuner left' {
        $hits = Select-String -Path @("$Root\Akari.ps1", "$Root\UI\*.ps1", "$Root\UI\*.xaml") -Pattern 'Tuner|Read-Prio|Read-Svc|SvcCur'
        @($hits).Count | Should Be 0
    }
}
