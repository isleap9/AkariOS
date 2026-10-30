# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 Ultimate Cleanup "Disk Cleanup Options":
# its categories as a saved Disk Cleanup set (StateFlags0069), run with cleanmgr /sagerun:69. Left out of ZOICWARE's
# list: Recycle Bin (the user's files) and Windows ESD installation files (Reset this PC needs them). Only categories
# this Windows has are set.
# Action: cleaned files can't come back.
@{
    Id          = 'cleanup-disk-cleanup'
    Name        = 'Run Disk Cleanup'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Runs Disk Cleanup on its own with every category but the Recycle Bin and the reset files: update leftovers, old Windows installations, caches, error reports, logs, old driver packages. It can take a while.'
    Confirm     = 'Run Disk Cleanup now? It deletes update leftovers and previous Windows installations (no going back to them) and may take several minutes.'
    Apply       = {
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
        $set = 0
        foreach ($c in 'Active Setup Temp Folders', 'Thumbnail Cache', 'Delivery Optimization Files', 'D3D Shader Cache', 'Downloaded Program Files',
            'Internet Cache Files', 'Setup Log Files', 'Temporary Files', 'Windows Error Reporting Files', 'Offline Pages Files',
            'Temporary Setup Files', 'Update Cleanup', 'Upgrade Discarded Files', 'Windows Defender', 'Windows Reset Log Files',
            'Windows Upgrade Log Files', 'Previous Installations', 'Old ChkDsk Files', 'Feedback Hub Archive log files',
            'Diagnostic Data Viewer database files', 'Device Driver Packages') {
            if (Get-AkariRegKey "$k\$c") { Set-Reg "$k\$c" 'StateFlags0069' 2 'DWord'; $set++ }
        }
        if (-not $set) { throw 'Disk Cleanup has none of its categories on this PC' }
        Invoke-AkariCleanMgr 69
        "Disk Cleanup ran with $set categories"
    }
}
