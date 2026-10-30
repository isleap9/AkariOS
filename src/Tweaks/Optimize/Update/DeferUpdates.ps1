# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Security Updates Only": group policies
# (Pro and up; Home ignores them), ZOICWARE's values as they are (730 days, past the documented 365 / 30 day limits;
# the excluded classifications). Named for what it does: quality updates carry the security fixes, so they wait too.
# Its SetAllowOptionalContent is update-block-driver-updates-policy's. Revert deletes the policies.
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$excluded = @(
    '{e6cf1350-c01b-414d-a61f-263d3d4dd9f9}', '{e0789628-ce08-4437-be74-2495b842f43b}', '{b54e7d24-7add-49f4-88bb-9837d47477fb}',
    '{68c5b0a3-d1a6-4553-ae49-01d3a7827828}', '{b4832bd8-e735-4766-9727-7d0ffa644277}', '{28bc8804-5382-4bae-93aa-13c905f28542}',
    '{cd5ffd1e-e257-4a05-9d88-c83a7125d4c9}', '{0f1afbec-90ef-4651-9e37-030fedc944c8}', '{ebfc1fc5-71a4-4f7b-9aca-3b9a503104a0}',
    '{9920c092-3d99-4a1b-865a-673135c5a4fc}') -join ';'
@{
    Id          = 'update-defer-policy'
    Name        = 'Defer feature and quality updates (group policy)'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Advanced'
    Requires    = 'Pro'
    Guided      = $false
    Description = 'Feature and quality updates wait as long as Windows allows, and critical, definition, driver, feature pack, tool and rollup updates are left out. Security fixes come with quality updates, so they wait too.'
    Registry    = @(
        @{ Path = $wu; Name = 'DeferFeatureUpdates'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = $wu; Name = 'DeferFeatureUpdatesPeriodInDays'; Type = 'DWord'; Value = 730; Default = $null }
        @{ Path = $wu; Name = 'DeferQualityUpdates'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = $wu; Name = 'DeferQualityUpdatesPeriodInDays'; Type = 'DWord'; Value = 730; Default = $null }
        @{ Path = $wu; Name = 'ExcludeUpdateClassifications'; Type = 'String'; Value = $excluded; Default = $null }
    )
}
