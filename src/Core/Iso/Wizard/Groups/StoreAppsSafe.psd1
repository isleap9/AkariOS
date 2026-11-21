# ISO Builder removal group (plan docs/plans/2026-11-20-iso-builder-wizard.md, Modes): the image's Store apps that
# Win11Debloat rates safe to remove (the appx Group's rows with Risk Safe, not Keep: src/Tweaks/Apps/Remove/Appx.psd1).
# Apps: 'appx:Safe' = those rows' package names, matched on the image's provisioned apps when it is built.
@{
    Name        = 'Store apps safe to remove'
    Description = 'News, Weather, Solitaire, Clipchamp and the other Store apps rated safe to remove. The Store, Calculator, Photos and Notepad stay.'
    Kind        = 'Apps'
    Risk        = 'Safe'
    Order       = 3
    Apps        = @('appx:Safe')
}
