# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): the Store apps the AkariOS
# preset removes (its "appx/*" = the appx Group's rows not Keep, FR33THY's pick: src/Tweaks/Apps/Remove/Appx.psd1).
# Apps: 'appx:AkariOS' = those rows' package names, matched on the image's provisioned apps when it is built.
@{
    Name        = 'Store apps AkariOS removes'
    Description = 'Every Store app but FR33THY''s keep-list, as One-click removes them. The Store, Calculator, Photos and the runtimes stay.'
    Kind        = 'Apps'
    Risk        = 'Caution'
    Order       = 4
    Apps        = @('appx:AkariOS')
}
