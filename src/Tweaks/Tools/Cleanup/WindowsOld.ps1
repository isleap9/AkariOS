# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Remove Windows.old Folder" (Ultimate
# Cleanup): as TrustedInstaller, then taken over by the administrators and deleted.
# Action: the old Windows is gone for good.
@{
    Id          = 'cleanup-windows-old'
    Name        = 'Delete Windows.old'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Deletes the previous Windows that an upgrade or reinstall kept in C:\Windows.old (often 10 GB or more). Going back to that Windows is no longer possible.'
    Confirm     = 'Delete Windows.old? You can no longer go back to the previous Windows or copy files out of it.'
    Apply       = {
        $p = "$env:SystemDrive\Windows.old"
        if (-not (Test-Path -LiteralPath $p)) { return 'There is no Windows.old folder' }
        Run-Trusted "Remove-Item -LiteralPath '$p' -Recurse -Force -ErrorAction SilentlyContinue"
        Grant-AkariOwnership $p
        $null = Remove-AkariPaths @($p)
        if (Test-Path -LiteralPath $p) { 'Some of Windows.old is still in use; restart and run this again' } else { 'Windows.old deleted' }
    }
}
