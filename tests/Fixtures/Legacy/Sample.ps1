Add-Tweak -Id 'legacy-toggle' -Category 'Windows' -Name 'Legacy toggle' -Risk Safe `
    -Description 'Fixture: legacy Toggle' `
    -Apply { Write-Host 'on' } -Revert { Write-Host 'off' } -Detect { $true }

Add-Tweak -Id 'legacy-group' -Category 'Advanced' -Kind Group -Name 'Legacy group' -Risk Caution `
    -Description 'Fixture: legacy Group' `
    -Actions @(
        @{ Name = 'One'; Description = 'Fixture action'; Button = 'Apply'; Block = { Write-Host 'one' } }
    )
