# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar (attrib +h, done through .NET here).
@{
    Id          = 'start-hide-accessibility-folders'
    Name        = 'Hide Accessibility and Accessories in Start'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Hides the Accessibility and Windows Accessories folders (and everything in them) from All apps. The tools still work from search.'
    Detect      = {
        $dirs = @("$(Get-AkariUserFolder 'Programs')\Accessibility", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessibility",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories") | Where-Object { Test-Path -LiteralPath $_ }
        if (-not $dirs) { return 'Unknown' }
        $hidden = @($dirs | Where-Object { (Get-Item -LiteralPath $_ -Force).Attributes -band [IO.FileAttributes]::Hidden }).Count
        if ($hidden -eq @($dirs).Count) { 'Optimized' } elseif ($hidden -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        foreach ($d in @("$(Get-AkariUserFolder 'Programs')\Accessibility", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessibility",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories") | Where-Object { Test-Path -LiteralPath $_ }) {
            # like attrib: System files (desktop.ini) keep their attributes
            foreach ($i in @(Get-Item -LiteralPath $d -Force) + @(Get-ChildItem -LiteralPath $d -Recurse -Force) | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::System) }) {
                $i.Attributes = $i.Attributes -bor [IO.FileAttributes]::Hidden
            }
        }
    }
    Revert      = {
        foreach ($d in @("$(Get-AkariUserFolder 'Programs')\Accessibility", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessibility",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Accessories") | Where-Object { Test-Path -LiteralPath $_ }) {
            foreach ($i in @(Get-Item -LiteralPath $d -Force) + @(Get-ChildItem -LiteralPath $d -Recurse -Force) | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::System) }) {
                $i.Attributes = $i.Attributes -band (-bnot [IO.FileAttributes]::Hidden)
            }
        }
    }
}
