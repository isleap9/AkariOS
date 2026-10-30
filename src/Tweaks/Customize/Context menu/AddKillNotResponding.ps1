# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\killTasks.reg "Kill not Responding
# Tasks": a desktop menu entry (its .reg doubles the icon path's backslashes; one each here). Revert deletes the key.
$k = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\KillNotResponding'
@{
    Id          = 'context-add-kill-not-responding'
    Name        = 'Add Kill not responding tasks to the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop shows Kill not responding tasks, which force-closes every program that has stopped responding.'
    Registry    = @(
        @{ Path = $k; Name = 'Position'; Type = 'String'; Value = 'Top'; Default = $null }
        @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = '%SystemRoot%\System32\imageres.dll,-98'; Default = $null }
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = 'Kill not responding tasks'; Default = $null }
        @{ Path = "$k\Command"; Name = '(default)'; Type = 'String'; Value = 'cmd.exe /K taskkill.exe /F /FI "status eq NOT RESPONDING"'; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
