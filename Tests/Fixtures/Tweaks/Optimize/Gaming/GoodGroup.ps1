# Action: fixture data-list Group (fake package names, never installed anywhere)
@{
    Id          = 'good-group'
    Kind        = 'Group'
    Name        = 'Fixture GoodGroup'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Caution'
    Description = 'Fixture.'
    EntryKind   = 'AppxRemove'
    Entries     = @(
        @{ Name = 'Akari.Test.One'; Display = 'One'; Description = 'First'; Risk = 'Safe' }
        @{ Name = 'Akari.Test.Two'; Risk = 'Advanced'; Keep = $true }
    )
}
