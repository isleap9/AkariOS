# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Do not show delete synced file warning":
# the dialog's "don't show again" answer. Revert deletes it.
@{
    Id          = 'explorer-no-synced-delete-warning'
    Name        = 'No warning when deleting synced files'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Deleting a file in a synced folder (OneDrive and the like) no longer warns that it is deleted everywhere.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager'; Name = 'DoNotShowAgain'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
