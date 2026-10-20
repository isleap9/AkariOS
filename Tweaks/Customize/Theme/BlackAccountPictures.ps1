# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\7 User Account Pictures Black: the default account
# pictures painted black, the originals kept in ProgramData\User Account Pictures for Revert (as the script did).
@{
    Id          = 'theme-black-account-pictures'
    Name        = 'Black account pictures'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    Description = 'The default account picture (Start, sign-in screen, Settings) turns black. A picture you chose yourself stays.'
    # painted = user.png differs from the saved original
    Detect      = {
        $pic = "$env:ProgramData\Microsoft\User Account Pictures\user.png"
        $bak = "$env:ProgramData\User Account Pictures\user.png"
        if (-not (Test-Path -LiteralPath $bak)) { return 'Default' }
        if (-not (Test-Path -LiteralPath $pic)) { return 'Unknown' }
        if ((Get-FileHash -LiteralPath $pic).Hash -eq (Get-FileHash -LiteralPath $bak).Hash) { 'Default' } else { 'Optimized' }
    }
    Apply       = {
        $dir = "$env:ProgramData\Microsoft\User Account Pictures"
        if (-not (Test-Path -LiteralPath "$env:ProgramData\User Account Pictures")) { Copy-Item -LiteralPath $dir $env:ProgramData -Recurse -Force }
        Add-Type -AssemblyName System.Drawing
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -Recurse -File | Where-Object { $_.Extension -in '.png', '.bmp' })) {
            $b = [System.Drawing.Bitmap]::FromFile($f.FullName)
            $w = $b.Width; $h = $b.Height; $fmt = $b.RawFormat
            $b.Dispose()
            $n = New-Object System.Drawing.Bitmap $w, $h
            $g = [System.Drawing.Graphics]::FromImage($n)
            try { $g.Clear([System.Drawing.Color]::Black) } finally { $g.Dispose() }
            try { $n.Save($f.FullName, $fmt) } finally { $n.Dispose() }
        }
    }
    Revert      = {
        $bak = "$env:ProgramData\User Account Pictures"
        if (Test-Path -LiteralPath $bak) { Copy-Item "$bak\*" "$env:ProgramData\Microsoft\User Account Pictures" -Recurse -Force }
    }
}
