# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\6 Signout Lockscreen Wallpaper Black (the lock screen
# part; One-click does the same): a black image the size of the main screen, set through the lock screen policy.
@{
    Id          = 'theme-black-lock-screen'
    Name        = 'Black lock screen'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'A plain black lock screen and sign-in background instead of Windows Spotlight pictures.'
    Detect      = {
        $p = Get-AkariRegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP' 'LockScreenImagePath'
        if ($null -eq $p) { 'Default' }
        elseif ($p -eq "$env:SystemRoot\Black.jpg" -and (Test-Path -LiteralPath $p)) { 'Optimized' }
        else { 'Custom' }
    }
    Apply       = {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $size = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize
        $file = "$env:SystemRoot\Black.jpg"
        $bmp = New-Object System.Drawing.Bitmap $size.Width, $size.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try { $g.Clear([System.Drawing.Color]::Black) } finally { $g.Dispose() }
        try { $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Jpeg) } finally { $bmp.Dispose() }
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP' 'LockScreenImagePath' $file 'String'
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP' 'LockScreenImageStatus' 1
    }
    Revert      = {
        Remove-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP' 'LockScreenImagePath'
        Remove-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP' 'LockScreenImageStatus'
        Remove-Item "$env:SystemRoot\Black.jpg" -Force -ErrorAction SilentlyContinue
    }
}
