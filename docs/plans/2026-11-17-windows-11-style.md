# Windows 11 style: plan

Decided 2026-11-17. The crimson identity of the 2026-10-30 redesign (Unbounded / Manrope, Lucide, pills, glows, top
tabs, hero) gives way to a professional Windows 11 look: WinUI 3's colours, type ramp, control metrics and layout, a
left NavigationView, Segoe UI Variable, Fluent System Icons, and **the user's Windows accent colour**. The brand stays
in the logo (the crimson chevron). The reference is the AkariOS design system on claude.ai (the `AppWindow` card is
the whole window; every component card is a target render; its README is the brand book). Record the reversal in
`docs/adr/0008-windows-11-style.md` (supersedes ADR 0006's identity, keeps its theme mechanism).

Both apps change: `src/UI` (PowerShell) and `app/` (native), which loads `Theme.*.xaml`, `Icons.xaml`,
`Motion.xaml`, `Controls.xaml` and `MainWindow.xaml`'s window styles from `src/UI` (native-app plan, "Shared look").
Change the shared XAML once; then bring the native app's own views along in the same batch.

## Decisions

1. **Brushes.** Same mechanism (one theme dictionary, `DynamicResource` only), new values from the table below.
   Existing keys keep their names. **Removed:** `Glow`, `AccC` and every glow (`DropShadowEffect` in an accent colour,
   radial gradients). **Added:** `S1Alt Div Fly TxDis FocusIn Sub SubP CtlBd2 OkSoft BadSoft Info InfoSoft`.
2. **Accent at runtime.** `Acc AccH AccP AccT AccText AccSoft Info` follow the user's accent. PowerShell: read
   `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent\AccentPalette` (32 bytes, 8 RGBA:
   Light3, Light2, Light1, Base, Dark1, Dark2, Dark3, unused); native: `Windows.UI.ViewManagement.UISettings.GetColorValue`
   (AccentLight2 etc.). Dark: `Acc` = Light2, `AccText` = `Info` = Light3, `AccT` = black. Light: `Acc` = Dark1,
   `AccText` = `Info` = Dark2, `AccT` = white. `AccH` / `AccP` / `AccSoft` = `Acc` at 90 / 80 / 10%. `Set-AkariAccent`
   puts new brushes into the current theme dictionary after `Set-AkariTheme` and on `WM_SETTINGCHANGE` /
   `WM_DWMCOLORIZATIONCOLORCHANGED` (0x320) in the existing hook. Unreadable palette: keep the table's default blue.
3. **Type.** Segoe UI Variable, the Windows 11 ramp: Title Large 40/52, Title 28/36, Subtitle 20/28 (all Display,
   SemiBold), Body Large 18/24, Body Strong 14/20 SemiBold, Body 14/20, Caption 12/16 (Small). `FontDisplay` =
   `Segoe UI Variable Display, Segoe UI`, `FontText` = `Segoe UI Variable Text, Segoe UI`, new `FontSmall` =
   `Segoe UI Variable Small, Segoe UI`, `FontMono` = `Cascadia Mono, Consolas`. Delete `src/Assets/Fonts/` (and the
   native app's embedded copies), the font loading code, and the three OFL entries in CREDITS.md. Body weight 400.
4. **Icons.** Fluent System Icons (Microsoft, MIT), `@fluentui/svg-icons@1.1.344`, the 20px **regular** style, plus
   **filled** for the selected nav item and InfoBar severities. `build/Icons.ps1` reads those SVGs (filled paths,
   20 × 20 viewBox) instead of lucide's `icon-nodes.json`; `Icons.xaml` keeps the `Ic.<name>` keys (no call site
   changes) and adds `Ic.<name>.Filled` where needed; `New-AkariIcon` draws `Fill`, not `Stroke`. Mapping below.
   CREDITS.md: Lucide out, Fluent System Icons in.
5. **Layout: Windows 11 Settings.** Title bar 48px (back button, 16px logo, "AkariOS" + version in Caption, caption
   buttons; the options button goes). Left NavigationView, 280px, on Mica, collapsing to 48px under 1000px window
   width: search box, Home, Install AkariOS, Optimize, Downloads, Remove apps, Install USB, a divider, About.
   Selected item: `Sub` fill, 3 × 16 `Acc` pill (slides between items), filled icon in `AccText`. Optimize's
   Sections / Categories (today `SubNav` / `Chips`) become indented second-level nav items under Optimize. The
   content layer: `Surf`, 1px `Div` top and left edge, 8px top-left corner, content max 1000px, 36px side padding.
6. **Pages.** Page header = Title (28/36), or a breadcrumb (`Optimize › Advanced › Security`, parents in `Mu`); no
   header icon, no subtitle. Home: `Banner` (logo 72px, the line, accent + standard button, facts) and `Tile`s instead
   of the Hero and mode cards. Guided: `SettingsExpander` per Category instead of `CategoryCard`, the Review and result
   rows as `SettingsCard`s; `StepFooter` ("Step 2 of 4 · Tweaks", a progress bar, Back, the accent action) in the
   32px status line instead of the numbered stepper. Optimize › Advanced: a `SettingsCard` per Tweak. The update bar,
   restart and Safe Mode bars become `InfoBar`s. The options menu's items (Import / Export settings, Theme, System
   Restore, Logs, links) become Settings cards on About.
7. **Controls** (WinUI metrics): buttons 32px, 4px corners, 11px side padding, a `CtlBd2` bottom edge; accent button
   min 120px. ToggleSwitch 40 × 20, 12px thumb (14 on hover), "On" / "Off" label on its left. CheckBox 20px, 4px
   corners. RadioButton 20px. ComboBox 32px, drop-down with 8px corners and 32px rows. TextBox 32px with a 1px `Line`
   bottom edge, 2px `Acc` on focus. Settings card min 68px, 16px side padding, 4px apart, no shadow. Focus = Fluent's
   double ring (2px `Focus` outside, 1px `FocusIn` inside, 1px off the control) on every focusable control. Retire
   `Segmented`/`SegItem` (Choices use ComboBox), `Tab`, `Chip`, `ModeCardHot`, `StepNum`.
8. **Corners and shadows.** 4px (controls, cards, nav items, menu rows, tooltips, InfoBars), 8px (flyouts, menus,
   dialogs, tiles, banner, the content layer's corner), full for toggles and radios. Every 12 to 22px radius goes.
   Shadows only on tooltips, flyouts, dialogs and tiles on hover.
9. **Motion** (`Motion.xaml`): `Motion.Fast` 0:0:0.083, `Motion.Base` 0:0:0.167, `Motion.Slow` 0:0:0.25,
   `Motion.Ease` a decelerate curve (`ExponentialEase EaseOut Exponent 7`, close to WinUI's cubic-bezier(0,0,0,1)).
   `Motion.Spring` goes (no overshoot in Fluent). Page entrance: fade + 8px rise; no card stagger beyond the first 8.

## Theme values (WPF `#AARRGGBB`; Acc* are the default-blue fallbacks)

| Key | Dark | Light | Use |
|---|---|---|---|
| `Bg` | `#202020` | `#F3F3F3` | Window background without Mica (Windows 10), the dialog's button strip |
| `Tint` | `#D9202020` | `#D9F3F3F3` | Window body over Mica on Windows 11: Bg at 85% so the wallpaper tint shows through faintly |
| `Surf` | `#4D3A3A3A` | `#80FFFFFF` | The content layer right of the navigation pane, top-left corner rounded (radius-overlay) |
| `S1` | `#0DFFFFFF` | `#B3FFFFFF` | Settings cards, expanders, tiles |
| `S1Alt` | `#08FFFFFF` | `#80F6F6F6` | Nested rows inside an expanded SettingsExpander |
| `S2` | `#2C2C2C` | `#F9F9F9` | Flyouts, menus, combobox drop-downs and dialogs (solid stand-in for Acrylic) |
| `Bd` | `#1A000000` | `#0F000000` | 1px card stroke |
| `Div` | `#15FFFFFF` | `#0F000000` | Dividers between rows, the content layer's edge, the dialog footer rule |
| `Fly` | `#66757575` | `#0F000000` | 1px stroke of flyouts, menus and dialogs |
| `Tx` | `#FFFFFF` | `#E4000000` | Primary text and icons on every surface |
| `Mu` | `#C8FFFFFF` | `#9E000000` | Secondary text: descriptions, subtitles, the status line, icons in rows |
| `Ter` | `#8BFFFFFF` | `#8F000000` | Tertiary text (12px+): ids, versions, placeholder text. Light is darker than WinUI's TextFillColorTertiary so it passes 4.5:1 on cards |
| `TxDis` | `#5DFFFFFF` | `#5C000000` | Disabled text and icons. Not for information that must be read |
| `Acc` | `#4CC2FF` | `#0067C0` | Accent fill: primary buttons, on toggles, checked boxes and radios, the selection pill, progress, the focused text box underline. Runtime: dark = AccentLight2, light = AccentDark1 |
| `AccH` | `#E64CC2FF` | `#E60067C0` | Accent fill on hover (90%) |
| `AccP` | `#CC4CC2FF` | `#CC0067C0` | Accent fill while pressed (80%) |
| `AccT` | `#000000` | `#FFFFFF` | Text and glyphs on Acc, AccH, AccP |
| `AccText` | `#99EBFF` | `#003E92` | Accent as text: hyperlinks, the selected nav icon. Runtime: dark = AccentLight3, light = AccentDark2 |
| `AccSoft` | `#1A4CC2FF` | `#1A0067C0` | Selected list rows and the tile behind a page icon: the accent at 10% |
| `Focus` | `#FFFFFF` | `#E4000000` | Keyboard focus: the 2px outer ring, 1px outside the control, with FocusIn inside it |
| `FocusIn` | `#B3000000` | `#B3FFFFFF` | Keyboard focus: the 1px inner ring |
| `Sub` | `#0FFFFFFF` | `#09000000` | Subtle buttons, nav items and menu rows on hover; the selected nav item |
| `SubP` | `#0AFFFFFF` | `#06000000` | Subtle buttons and nav items while pressed |
| `Ctl` | `#0FFFFFFF` | `#B3FFFFFF` | Standard button, combobox and text box at rest; toggle track when off |
| `CtlH` | `#15FFFFFF` | `#80F9F9F9` | Controls on hover |
| `CtlP` | `#08FFFFFF` | `#4DF9F9F9` | Controls while pressed |
| `CtlBd` | `#12FFFFFF` | `#0F000000` | Control stroke (top and sides) |
| `CtlBd2` | `#18FFFFFF` | `#29000000` | Control stroke, bottom edge: the slight elevation WinUI draws under buttons |
| `Line` | `#8BFFFFFF` | `#72000000` | Strong strokes: the off toggle's outline and thumb, unchecked checkbox and radio, the text box underline at rest |
| `InFocus` | `#B31E1E1E` | `#FFFFFF` | Text box fill while it has keyboard focus |
| `Warn` | `#FCE100` | `#9D5D00` | Caution: the risk badge and InfoBar icon |
| `WarnSoft` | `#433519` | `#FFF4CE` | Caution InfoBar and badge background |
| `WarnT` | `#000000` | `#FFFFFF` | Text on a solid Warn badge (Advanced risk) |
| `Bad` | `#FF99A4` | `#C42B1C` | Critical: failed Outcomes, errors, the error InfoBar icon |
| `BadSoft` | `#442726` | `#FDE7E9` | Error InfoBar background |
| `Ok` | `#6CCB5F` | `#0F7B0F` | Success: Applied Outcomes, the ready dot, the success InfoBar icon |
| `OkSoft` | `#393D1B` | `#DFF6DD` | Success InfoBar background |
| `Info` | `#99EBFF` | `#005FB7` | Informational InfoBar icon (follows the accent's text colour at runtime) |
| `InfoSoft` | `#08FFFFFF` | `#80F6F6F6` | Informational InfoBar background |
| `Tip` | `#2C2C2C` | `#F9F9F9` | Tooltip fill |
| `TipBd` | `#33000000` | `#0F000000` | Tooltip stroke |
| `TipT` | `#FFFFFF` | `#E4000000` | Tooltip text |
| `Track` | `#8BFFFFFF` | `#72000000` | Progress bar track (1px) under the 3px Acc bar |
| `Scrim` | `#4D000000` | `#4D000000` | Dims the window under a dialog |
| `CloseH` | `#C42B1C` | `#C42B1C` | Title bar close button on hover |
| `CloseP` | `#C83C30` | `#C83C30` | Title bar close button pressed |
| `CloseT` | `#FFFFFF` | `#FFFFFF` | The close glyph on CloseH and CloseP |

Contrast was checked in the design system: every text colour passes 4.5:1 on Bg, Surf, S1 and S2 in both themes
(light `Ter` is darker than WinUI's on purpose), `Line` and `Acc` pass 3:1.

## Icon mapping (Ic.<key> → Fluent name, 20px regular)

| Ic key | Fluent |
|---|---|
| `accessibility` | `accessibility` |
| `activity` | `pulse` |
| `app-window` | `window` |
| `arrow-left` | `arrow_left` |
| `arrow-left-right` | `arrow_swap` |
| `arrow-right` | `arrow_right` |
| `bell` | `alert` |
| `blocks` | `apps_add_in` |
| `bug` | `bug` |
| `check` | `checkmark` |
| `chevron-down` | `chevron_down` |
| `circle-check` | `checkmark_circle` |
| `circle-help` | `question_circle` |
| `circle-minus` | `subtract_circle` |
| `circle-slash` | `prohibited` |
| `circle-x` | `dismiss_circle` |
| `cloud-download` | `cloud_arrow_down` |
| `copy` | `copy` |
| `cpu` | `developer_board` |
| `disc-3` | `storage` |
| `download` | `arrow_download` |
| `eraser` | `eraser` |
| `external-link` | `open` |
| `file-input` | `arrow_import` |
| `file-output` | `arrow_export_ltr` |
| `flask-conical` | `beaker` |
| `folder` | `folder` |
| `folder-open` | `folder_open` |
| `gamepad-2` | `games` |
| `gauge` | `top_speed` |
| `github` | `code` |
| `hard-drive` | `hard_drive` |
| `history` | `history` |
| `house` | `home` |
| `info` | `info` |
| `layout-grid` | `grid` |
| `list-checks` | `task_list_ltr` |
| `lock` | `lock_closed` |
| `menu` | `navigation` |
| `message-circle` | `chat` |
| `minus` | `subtract` |
| `monitor` | `desktop` |
| `mouse` | `cursor` |
| `palette` | `color` |
| `panel-bottom` | `panel_bottom` |
| `power` | `power` |
| `refresh-cw` | `arrow_sync` |
| `rotate-ccw` | `arrow_counterclockwise` |
| `search` | `search` |
| `settings` | `settings` |
| `settings-2` | `options` |
| `shield` | `shield` |
| `shield-check` | `shield_checkmark` |
| `sliders-horizontal` | `options` |
| `sliders-vertical` | `slide_settings` |
| `square` | `maximize` |
| `sun-moon` | `dark_theme` |
| `trash-2` | `delete` |
| `triangle-alert` | `warning` |
| `undo-2` | `arrow_undo` |
| `usb` | `usb_stick` |
| `volume-2` | `speaker_2` |
| `wifi` | `wifi_1` |
| `wrench` | `wrench` |
| `x` | `dismiss` |
| `zap` | `flash` |

`github` has no Fluent equivalent (no brand icons); `code` stands in, or keep the GitHub mark as a separate geometry.
Filled variants needed: the seven nav pages (`home flash options arrow_download delete usb_stick info`) and
`info warning error_circle checkmark_circle` for InfoBars.

## Batches (each: tests, screenshots of every page in dark and light, diffstat, the user's go, commit)

1. **Tokens and accent.** New theme values, added and removed keys, `Set-AkariAccent` (both apps), glows removed.
   The app keeps its current layout but turns grey-and-accent. Tests: both theme files hold the same keys; every key
   the UI names exists; no `Glow` / `AccC` left; the palette parser maps a sample `AccentPalette` to the right brushes.
2. **Type.** Segoe ramp, `FontSmall`, fonts folder and loader removed. Test: no `Unbounded` / `Manrope` /
   `JetBrains` anywhere in `src/` or `app/`.
3. **Icons.** `build/Icons.ps1` on Fluent, `Icons.xaml` regenerated with the same keys plus `.Filled`, fill-based
   `New-AkariIcon`. Test: every `Ic.*` key used exists; every geometry parses.
4. **Controls.** Metrics, focus ring, motion values, retired styles. Test: `Controls.xaml` defines every style still
   used; no `CornerRadius` above 8 except toggles and radios.
5. **Shell.** Title bar, NavigationView (with collapse), content layer, breadcrumb header, status line and step
   footer; options menu moved to About. Rewrite the `Shell navigation` tests for the nav pane (each page reachable,
   Optimize's second level, Back from flows).
6. **Pages.** Home banner and tiles, Guided expanders, Review / result cards, Advanced settings cards, InfoBars,
   dialogs (WinUI ContentDialog: 8px corners, equal-width footer buttons, no corner icon).
7. **Native parity and the VM.** The native app's views match batch 5 and 6; Windows 10 22H2 and 11 24H2, 100% and
   150%, dark and light, a non-default accent (e.g. green) and the default, Mica on and off; One-click and Guided
   end to end.

## Rules

- Everything in the earlier plans' Rules still holds: themes by `DynamicResource`, no hex outside the theme files,
  ASCII-only UI files without a BOM, animations only on Opacity / transforms through `Motion`.
- When unsure how something should look, do what Windows 11 Settings does, then check the design system's card.
- Nothing in the UI is crimson except the logo.
