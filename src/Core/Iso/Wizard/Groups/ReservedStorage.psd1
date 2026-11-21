# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): reserved storage off from the
# first boot. ShippedWithReserves = 0 is the value Microsoft documents for turning it off in an image before setup.
@{
    Name        = 'Reserved storage'
    Description = 'Windows doesn''t hold back about 7 GB of disk for updates. Updates still install; one may ask for free space first.'
    Kind        = 'Settings'
    Risk        = 'Safe'
    Order       = 8
    Registry    = @(
        @{ Path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager'; Name = 'ShippedWithReserves'; Type = 'DWord'; Value = 0 }
    )
}
