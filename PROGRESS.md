# ricegueh quickshell — Progress Notes

Custom Quickshell shell at `/home/notfuad/.config/quickshell/ricegueh/`, replacing
swaync + waybar with native notifications/notification center, quick settings,
audio controls, MPRIS detail popup, and a morphing-hover bar.

## Environment
- Hyprland 0.56.2 (lua config), quickshell 0.3.0.
- Screens: eDP-1 1366x768 at x=0, HDMI-A-1 1366x768 at x=1366. Bars 30x758,
  popup card top-right.
- `preserve_workspaces` unset -> empty workspaces destroyed; `Hyprland.workspaces.values`
  + `Hyprland.focusedWorkspace` verified in qmltypes.

## Restart / verify
```
pkill -x quickshell; sleep 1; setsid nohup quickshell -c ricegueh >/tmp/opencode/qs.log 2>&1 < /dev/null & sleep 6; pgrep -x quickshell && echo RUNNING
grep -iE "error|failed" /tmp/opencode/qs.log | head
```
(plain `nohup`/`&` without `setsid` dies silently once the shell exits; always use
`setsid nohup ... < /dev/null &`.)

## QML / Quickshell quirks (learned the hard way)
- Timers in invisible windows don't fire; changes inside `Timer.onTriggered` don't
  propagate across window bindings. Prefer signal-driven flows; `Connections` work.
- Bare ids only in some contexts (`card.inAnim` undefined). JS objects are COPIED
  across `property var`; QObject refs stored DIRECTLY in a property survive
  (`e.card === card`), but QObjects nested inside a copied JS object do NOT.
- Explicit animation (`ParallelAnimation` + `restart()`) works; `Behavior` on bound
  values doesn't visibly play for newly-unmapped windows.
- `on<Signal>Changed` must attach to the object owning the property (else
  `Cannot assign to non-existent property`).
- Signal-handler param names shadow outer property names: `onExpandToggled: x = expanded`
  NOT `x = checked` (checked resolved to the ToggleRow's own `checked` -> dropdown
  never closed; real "can't close" bug).
- MouseArea ordering: a topmost MouseArea with `acceptedButtons: Qt.LeftButton`
  steals clicks from Switch/chevron below it. ToggleRow's row-click `ma` = FIRST
  child; swallow MouseArea lives INSIDE the card (not the window) so outside
  clicks close the panel.
- `player.position`/`length` (Quickshell.Services.Mpris MprisPlayer) are in
  **SECONDS**, not ms. They don't update reactively while playing — re-read them
  on a tick (read returns current value even without signal).
- `UPower` `percentage` is 0..1 double (x100 for display).
- `Quickshell.Io.IpcHandler`: `target` property; typed functions
  (`function toggleNotifications(): void`); CLI: `quickshell ipc -c ricegueh call
  ricegueh <fn>` (`-c` BEFORE subcommand; `quickshell ipc -c ricegueh show` lists).
- `MprisPlayer` qmltypes has `position`, `positionSupported`, `length`, `lengthSupported`.
- Click injection impossible (xdotool X11 can't hit Wayland layer surfaces) —
  all click/hover behavior user-tested.
- Qt 6 no longer injects signal-handler params: `function onQuickSettingsOpenChanged(open)`
  receives `open === undefined`. Always read the state directly (e.g.
  `ShellState.quickSettingsOpen`). Root cause of the "No IP" ethernet bug.
- Base component ids invisible from subclasses: `ReferenceError: card is not defined`
  in QuickSettings. Expose helpers on the base instead (ShellPopup `cardBottom`).
- QML treats a property starting with `on`+Uppercase as a SIGNAL HANDLER:
  `onAccent` → "Cannot assign a value to a signal". Rename (we used `accentText`).
- `Quickshell.reload(hard: bool)` REQUIRES its argument (`reload()` → "Insufficient
  arguments"); `Quickshell.configDir` is deprecated → `Quickshell.shellDir`.
- Pipewire node `type` masks: `AudioSource=9` (Source|Audio), `AudioSink=17`
  (Sink|Audio), `Stream=4`. A stream's `Audio` bit sets off the `AudioSource`
  mask even with no Source bit → app streams land in BOTH device lists.
- matugen template syntax: `<* *>` control blocks, `{{ colors.<role>.default.hex }}`.
  Generated QML gets auto-reloaded by quickshell's file watcher (it watches the
  config dir) — no manual restart needed.
- MouseArea built-in signal handlers: Qt6.7+ warns that implicit `mouse` param
  injection is deprecated — use `onClicked: (mouse) => { ... }`.
- SNI menus: `StatusNotifierItem.menu` is a DBusMenuHandle shown with
  `QsMenuAnchor { menu: <item>.menu; anchor.item: <icon>; edges/gravity }` +
  `open()`; `anchor.updateAnchor()` recomputes the rect if the item moved.
  `ItemIsMenu` (quickshell `onlyMenu`) is FALSE for Discord/KDE Connect here.

## Bar / widget layout
- shell.qml bar Variants -> modulesHost + shared `hoverBar` Rectangle
  (width barWidth-6, x 3, radius 5, Behaviors y/height 140ms, opacity 120ms).
- topGroup (Column): Swaync, Clock, VolumeGroup, Orbit, Tray.
- Mpris centered (`anchors.centerIn: parent`), `visible: root.player != null`.
- bottomGroup (Column): Backlight, Temperature, Battery, Workspaces, IdleInhibitor.

## Completed work
- **Notifications**: native NotificationServer in shell.qml (actions/body/image
  supported). Every notification is `tracked = true`. Toast queue (dynamic
  cards), DND, clear-all with slide-out animation (NotificationCenter
  `slideOutClear()`), `toastClearTick` dismiss. Toast cards collapse on expiry,
  one outbox anim at a time. Notifications add to history (`addHistory` stores
  the live `real` Notification object so the panel can dismiss on the daemon);
  `clearHistory()` bumps `toastClearTick`; `dismissHistory(id)` = real.dismiss()
  + removeHistoryById.
- **IMPORTANT: the server has NO built-in window** (verified in source
  server.cpp — it's a pure daemon; untracked notifications just get dismissed).
  A "regular window" notification means ANOTHER daemon owns
  `org.freedesktop.Notifications` (xfce4-notifyd is activatable + in
  `/etc/xdg/autostart/xfce4-notifyd.desktop`; there's ALSO a systemd-activated
  `dunst.service` on this system). If one activates while quickshell
  is down it steals the name until killed (quickshell's watcher only re-registers
  on unregistration). Fix: shell.qml `Component.onCompleted` runs
  `pkill -x xfce4-notifyd; pkill -x dunst; pkill -x mako; pkill -x swaync`
  (self-heals), hyprland.lua line 66 does the same before `qs -c ricegueh`, and
  `~/.config/autostart/xfce4-notifyd.desktop` = Hidden=true disables xdg autostart.
- **Notification panel interactions**: swipe a card left/right past 60px (or
  right-click) to dismiss it (slide-out anim + `dismissHistory`); group header
  has a hover-brightening "× clear" button to dismiss ALL from that app.
- **Images**: ToastCard + NotificationCard now show the notification image as a
  rounded 40x40 LEFT thumbnail (messenger style); if the image is avatar-sized
  it's the thumb, if LARGE (>160px natural height) it renders as a big body
  image (140/160px) and the app icon is the thumb instead. `addHistory` stores
  `image`. Quickshell's `image` property covers `image-data`/`image_data`/
  `icon_data` raw-byte hints AND `image-path`/`image_path` (notification.cpp
  updateProperties). NOTE: quickshell can FREEZE decoding a mislabeled image
  file (a `.jpeg` that was really AVIF 3000x1688 hung the process; real PNGs
  fine) — server-side bug, not ours.
- **Morphing hover highlight**: `ShellState.barHover {y,height}` +
  `barHoverTracker` (direct QObject ref). HoverHighlight.qml reports rect in bar
  coords; clearTimer 100ms clears only if tracker still matches owner. `host`
  property wired into Swaync/Clock/Volume/VolumeGroup/Microphone/Orbit/Mpris/
  Backlight/Temperature. Bar hoverBar opacity `ShellState.barHover ? 1 : 0`
  (removed a `barHoverArea.containsMouse` gate that broke it).
- **Hover fade-out delay + morph (user request)**: HoverHighlight `clearDelay`
  100 -> 2000ms so the highlight lingers 2s while the cursor travels between
  icons. Bar hoverBar now keeps a `lastHover` rect (updated via
  `onHoverTargetChanged` when a NEW target arrives) and holds y/height at it
  while fading out instead of collapsing to y:0/height:0 — fixes the
  "appearing/disappearing from the top" look; a re-hover morphs from the held
  position to the new one. NOTE: inside that block use the `hoverBar` id, NOT
  `root` (root = the ShellRoot in shell.qml scope!). New `Config.barPaddingV`
  (10) replaces `barBorderWidth + modulePaddingV` as topGroup/bottomGroup
  topMargin/bottomMargin.
- **QuickSettings**: grid actions (close popup on click), ToggleRow expandable
  rows (wifi list, audio device list, nightlight slider, idle inhibit). Row click
  toggles dropdown; Switch/chevron first-child ordering. Expanded flags reset on
  open; wifi list refreshed via `refreshWifi()`, 3s timer while open, Flickable
  height 86 (3 rows). Nightlight toggle is OPTIMISTIC (flip immediately, then
  start wlsunset / `pkill wlsunset`). Lock action runs `hyprlock` directly
  (was LockScreen.sh). Wifi `onExpandToggled: wifiExpanded = expanded` fix.
- **ExpandableSection** (`widgets/ExpandableSection.qml`): reusable animated
  dropdown — animates `animHeight` (Behavior, InOutCubic) + opacity fade + clip
  instead of snapping `visible`. `implicitHeight: animHeight` feeds the popup
  card (ShellPopup `height: body.implicitHeight + padding*2` + Behavior) so the
  whole card morphs smoothly. Wifi/ethernet/bluetooth/nightlight dropdowns now
  wrapped in it (their `visible:` toggles removed). Section `visible:`
  `(expanded && enabled) || animHeight > 1` so no dead spacing remains between
  rows once fully collapsed. Verified: Qt Column implicitHeight DOES include
  children with explicit heights (standalone test: two Items h40/h30 + spacing 8
  -> implicitHeight 78), so no `implicitHeight` needed on row widgets.
- **Audio**: VolumeGroup -> AudioControls popup (sink/source sliders + device rows).
- **MPRIS**: bar label (RotatedText, prefers playing player; counts players with
  `isPlaying || trackTitle` so playerless playerctld stays hidden; widget
  `visible: root.player != null`). Detail popup: art, title/artist/album,
  progress bar, time labels, transport buttons. Time labels use `formatTime(s)`
  on seconds (NOT ms) re-read on 500ms `tick`.
- **Orbit**: "<" in round ball, rotates 180° to ">" when quick settings open.
- **Battery**: iterates `UPower.devices.values`, capacity `percentage * 100`,
  text `X% <icon>`.
- **Workspaces**: only real workspaces; sliding window of 5 when >5 centered on
  focused; click -> `Hyprland.dispatch("workspace", modelData.id)`. Color flip
  (user): selected number is now BRIGHT (`Config.accent`), unselected DARK
  (`Config.activeWorkspace`) — the matugen palette had activeWorkspace as the
  dark green `#003822` and accent as the bright `#0bd790`, i.e. inverted.
- **IdleInhibitor**: optimistic toggle, no polling; refresh on popup open. Active
  icon/label now DARK (`Config.background`) on the bright toggleOn background
  (was `#ffffff`), matching the mirror button's inverted look.
- **MirrorScreen** (replaces the Airplane QuickAction in the quick-settings
  grid): mirrors eDP-1 onto HDMI-A-1 or stops it. Three states read from
  `hyprctl -j monitors all`: 󰞊 greyed/disabled when HDMI-A-1 absent or
  `disabled: true` (unplugged); 󰄘 `Config.primary` when connected + `mirrorOf:
  "none"` (click -> `hyprctl eval 'hl.monitor({ output = "HDMI-A-1", mode =
  "preferred", position = "auto", scale = 1, mirror = "eDP-1" })'`); 󰄙
  toggleOn-highlighted + dark icon when mirroring (click -> `hyprctl reload`).
  CRITICAL: while mirroring the HDMI output VANISHES from the active
  `hyprctl monitors` list (it's a slave) and only appears in `monitors all`
  with `mirrorOf` = the source id/name (not "none") — detecting via the active
  list made the button grey out and unclickable mid-mirror. Re-polls 800ms
  after a click + whenever the popup opens (Process with `StdioCollector`).
- **ShellPopup**: explicit slide-from-right open animation (`onEffectiveOpenChanged`
  at root: slideX = rightMargin+popupWidth+8, fade 0, openAnim.restart(); close ->
  reset). Swallow MouseArea inside card for outside-click close.
- **Config**: pixelSize 12, moduleSpacing 8, borders/popupBorder -> Config.primary.
- **Toast below quick settings**: Toast.qml `toastTop` moves the toast host down
  under the quick settings card instead of being covered by it
  (`ShellState.quickSettingsBottom + 8` when the popup is open). QuickSettings
  syncs the card's bottom edge into `ShellState.quickSettingsBottom` via a
  `Binding { value: root.cardBottom }` (cardBottom exposed on ShellPopup because
  the base `card` id is invisible from the subclass). Verified via hyprctl layers:
  toast at y=347, card bottom at 339.
- **Toast below audio controls too**: toasts now sit below whichever panel is
  open. `ShellState.audioControlsBottom` mirrors `quickSettingsBottom`; AudioControls
  syncs it via the same `Binding { value: root.cardBottom }` pattern. Toast.qml
  `toastTop` now resolves: quick settings open -> `quickSettingsBottom + 8`,
  else audio controls open -> `audioControlsBottom + 8`, else `Config.barMarginTop`
  (the open-flag gates each so a stale bottom is never used).
- **Calendar popup (click the clock)**: clicking the clock no longer toggles
  clock/date — it opens a Calendar popup (`widgets/Calendar.qml`, ShellPopup).
  Header shows the shown month+year with `« ‹ › »` month/year navigation
  (`NavButton.qml`, a small hoverable icon button). A subtitle shows the full
  current date ("Today · Sunday, August 17, 2026"). A 6x7 day grid fills the card
  at fixed height: today is a filled accent circle, in-month days normal text,
  adjacent-month days dimmed. `ShellState.calendarOpen` + `openCalendar(screen)`;
  `ShellState.calendarBottom` synced via the same cardBottom Binding so toasts
  also drop below the calendar when open (Toast.qml `toastTop` gained a third
  branch). `onOpenChanged` resets to today's month/year each time it opens.
  Grid sizing gotcha: `cellW = (grid.width - spacing*6)/7` so columns exactly
  fill the card width (otherwise Grid's internal spacing overflows/clips); the
  weekday header is a Grid with the same spacing so its labels align with the
  day columns. Reset `root.month`/`root.year` (NOT `today`, which is a var copy
  evaluated once).
- **Big-vs-avatar image heuristic (toast + notification cards)**: was
  `sourceSize.height > 160`, which misfired on large square avatars (Discord's
  256x256 default pfp, WhatsApp from Firefox) and rendered them as a big body
  image below the text. Now `Config.isBigImage(w, h)` = `w > h*1.2 && h > 160`:
  only clearly-landscape large media (screenshots, video thumbnails) renders
  below the text; square avatars always go to the left thumbnail. Applied
  consistently to ToastCard.qml and NotificationCard.qml (thumbSource + the
  bigImage `visible` check).
- **Notification bell margin (user: "above and below the bell icon too much")**:
  Swaync.qml box height `Config.iconHeight` (20) -> fixed 15 and glyph pixelSize
  12 -> 13. The nerd-font bell carries a lot of font-internal vertical whitespace,
  so a 20px box left empty space above/below the icon. `Config.iconHeight` still
  used by Orbit + KeyboardLayout.
- **matugen color integration**: colors now come from matugen, not hardcoded.
  - Template `~/.config/matugen/templates/quickshell-colors.qml` (lives in the
    `matugen-themes` repo, symlinked) → outputs `matugen-colors.qml` into the
    config root: material roles background/text/primary/secondary/accent/accentText/
    activeWorkspace/critical/surfaceContainer/High. Mappings follow waybar's:
    background=surface, text=on_surface, accent=primary_container.
  - `~/.config/matugen/config.toml` `[templates.quickshell]` entry with
    `post_hook = 'quickshell ipc -c ricegueh call ricegueh reload'`.
  - Config.qml loads it via `Qt.createComponent(Quickshell.shellDir + "/matugen-colors.qml")`
    in `loadPalette()`; `mpalette` is null until ready so every color falls back
    to the old values; alpha-based colors built with `withAlpha(c, a)` on the
    loaded hex. Verified applied: bar border pixel = #adc6ff (matugen primary).
    Regenerate with `matugen image <wallpaper> --prefer darkness`.
- **Audio controls polish**: (1) separator Item (14px + 1px line) between output
  and input sections. (2) Mute toggles now use the custom macOS-style Switch.qml
  (removed `import QtQuick.Controls`, which was silently resolving `Switch` to
  QtQuick's default control) — identical to quick-settings toggles. (3) Device
  lists exclude `PwNodeType.Stream` nodes: firefox's playback stream (type
  Sink|Stream|Audio) appeared in BOTH lists (its Audio bit tripped the
  AudioSource mask) and was unpressable; real devices only now.
- **Tray context menus**: right-click on a tray icon opens its DBus menu via
  `QsMenuAnchor` (menu: modelData.menu, anchor.item: the icon, edges Top|Left,
  gravity Bottom|Left + margins.left 6 → menu drops to the LEFT of the right-edge
  bar). Left-click still `activate()` (works for Discord, ItemIsMenu=false),
  middle = secondaryActivate(); left-click on `onlyMenu` items opens the menu.
  `anchor.updateAnchor()` called before open so the rect is fresh. Verified both
  registered items (Discord, KDE Connect) expose a Menu path.

## OSD overlay (caps/num lock, touchpad, volume, brightness)
- A single `PanelWindow` (`widgets/Osd.qml`, namespace `"osd"`) shows a
  bottom-center card when caps/num lock toggles, the touchpad is disabled, or
  volume/brightness changes. Slide in/out is driven by a dedicated Hyprland
  layer rule (see below) so the generic `quickshell` rule's `slide right`
  doesn't affect it.
- **Driven by `widgets/OsdMonitor.qml`** -> sets `ShellState.osd*` + a 2s
  `hideTimer`. Four sources:
  - Locks: poll `hyprctl -j devices` every 200ms (Hyprland has no LED-change
    event) and diff. Tracks EVERY keyboard in a `kbState` map (not just the
    "main" one — which device is main can shift). First poll = baseline, changes
    after that trigger the OSD.
  - Touchpad: `TouchPad.sh` toggles the device via `hyprctl eval
    "hl.device({...})"` and writes its state to `$XDG_RUNTIME_DIR/touchpad.status`
    (true/false); OsdMonitor polls that file every 200ms and diffs. First read
    (missing file = "true") is the baseline.
  - Volume: Pipewire `defaultAudioSink` observed through `Binding`s into
    `sinkVolume`/`sinkMuted` (handles the sink appearing/switching + changes
    without manual signal connections); first change is the baseline, real
    changes trigger. `osdPercent = round(volume*100)`, `osdMuted` saved.
  - Brightness: poll `/sys/class/backlight/*/brightness` + `max_brightness` via
    a shell Process every 300ms (OSD) / 2s (bar `Backlight.qml`), diff against
    last percent. Deliberately left as polling: the screen updates faster than
    the OSD/bar, and making it event-driven like volume was evaluated
    (`brightnessctl monitor` — raw value per change, no max/percent, so it was
    not adopted); user accepted the current behavior.
- **`ShellState` OSD fields**: `osdVisible`, `osdScreen` (the screen the pointer
  was on at trigger), `osdType` ("lock"|"touchpad"|"volume"|"brightness"),
  `osdLabel` (lock/touchpad), `osdOn` (lock/touchpad), `osdPercent` (0-100),
  `osdMuted` (volume).
- **Osd.qml layout**: box morphs width via `Behavior on width` — lock/touchpad
  180, brightness/volume 230 (both wide). Lock/touchpad share one layout:
  glyph + label + ON/OFF (touchpad glyph 󰟸 `md-trackpad` when on, slashed 󰤳
  `md-trackpad_lock` when off).
  Brightness/volume share a meter layout: icon + `%` text + a 6px meter bar
  anchored to fill the box width (18px margins), fill width animated. Clicking
  the box does nothing: `mask: Region {}` (0×0) makes the whole window
  click-through, so underlying windows keep working.
- **Volume icons** (nerd-font MDI): ≤30% = `󰕿` volume-low, ≤70% = `󰖀`
  volume-medium, else `󰕾` volume-high, muted = `󰸈`. (Earlier they were
  accidentally the MDI *alert* glyphs 0xf0026/7/8 — the "!" in triangle/box/
  circle the user saw — replaced with the proper speaker glyphs.)
- **TouchPad.sh FIXED** (`~/.config/hypr/scripts/TouchPad.sh`): it used the
  legacy `hyprctl keyword device:...:enabled` syntax which FAILS on Hyprland
  0.55+ lua configs ("keyword can't work with non-legacy parsers. Use eval.")
  and required `$Touchpad_Device` from a nonexistent Laptops.conf. Rewritten to
  auto-detect the first `*-touchpad` device from `hyprctl -j devices` and toggle
  via `hyprctl eval "hl.device({ name = '<dev>', enabled = true/false })"`,
  writing its state to the status file (which OsdMonitor polls). Accepts an
  explicit `on`/`off` arg (only acts on actual change). The laptop button emits
  SEPARATE `XF86TouchpadOn`/`XF86TouchpadOff` keys (not one toggle), so
  hyprland.lua (lines ~516-520) binds BOTH to `TouchPad.sh on`/`off` plus the
  `xf86TouchpadToggle` toggle — otherwise the firmware-level disable happened but
  the script never ran and no OSD appeared.
- **Width gotcha**: `ydotoold`/ydotool absolute mouse coords scale 0.95 against
  this 1366px screen (ydotool(500,500) → cursor(475,475)); scale
  screen/0.95 to click a spot. Click-through verified with real clicks: OSD
  surface never eats them.
- **Screenshot verify**: diff `grim` shots (OSD visible vs 3s-hidden) in the
  bottom band to isolate the box from app background; lock/touchpad box is
  x 593-772 (180 wide centered), volume/brightness x 568-797 (230), y 687-742.

## Notification action buttons (toasts + center)
- **Problem**: toasts rendered no action buttons at all (bluetooth pairing
  notification had no "Pair" button that swaync shows), and in both cards the
  swipe/drag MouseArea was declared AFTER the content, painting on top and
  swallowing clicks on the buttons.
- **`widgets/ActionButton.qml`** (new): small pill button (height 22, radius 11,
  `cardBackground` → `cardBackgroundHover` on hover, accent border) with optional
  nerd-font `icon` prefix, `text`, and `clicked` signal. Sizes itself via
  `implicitWidth` from its content Row.
- **ToastCard.qml / NotificationCard.qml**: added an action Row (Repeater over
  `notification.actions`, each button calls `action.invoke()`) plus a "󰅐 Copy
  code" button that appears when the body/summary contains a 6-digit number
  (KDE Connect pairing codes) and copies it via the writable
  `Quickshell.clipboardText`.
- **Z-order fix**: in both cards the full-card MouseArea (drag/swipe/right-click
  dismiss) is now declared BEFORE the content Column, so the action buttons
  (painted later) sit on top and receive clicks; non-interactive body items let
  events fall through to the swipe area below. Toast action click also dismisses
  the toast (`invoke()` + `dismiss()`); center card keeps it in history.
- Verified: accent-bordered buttons render inside the toast card (accent pixel
  cluster x 1045-1323 in the card region) with a synthetic
  `notify-send --action=pair:Pair` + a 6-digit-code notification. No QML errors.
  Real click still user-tested (no click injection).

## Toast hover freeze + opacity + close button
- **Freeze-on-hover (PAUSE, not reset)**: the toast auto-hide countdown
  (`hideTimeout` 5000ms) holds its remaining time while the cursor is over the
  card and resumes from there on leave. Implemented with explicit
  `pauseHideTimer()`/`resumeHideTimer()` tracking `hideRemaining`/`hideStartedAt`.
- **QML staleness trap (real bug)**: a bound property `hovered:
  dragArea.containsMouse || ...` read STALE inside a `onContainsMouseChanged`
  handler — on hover-enter it saw the old (false) value so it RESTARTED the
  timer instead of pausing (log showed `updateHideTimer hovered= false dm= true`
  → toast vanished after ~5s even while hovered). Fix: compute hover
  SYNCHRONOUSLY from `dragArea.containsMouse`/`buttonHover` directly inside
  `updateHideTimer()` instead of via a lazy binding. Also `startHideTimer()`
  calls `updateHideTimer()` at the end so a toast appearing under the cursor
  starts paused. (Same staleness rule applies to the opacity color — but there
  Qt re-evaluates the binding fine.)
- **Button hovers count too**: ActionButton exposes `readonly hovered` (its own
  `ma.containsMouse`); buttons and the close X report it via
  `card.onHoverChanged(h)` which bumps a `buttonHover` counter — they sit on top
  of the swipe MouseArea so they'd otherwise escape `dragArea.containsMouse`.
- **Opacity 0.5 → 0.9 on hover**: `color` switches between `Config.popupBackground`
  (alpha 0.5) and `Config.toastBackground` (new, alpha 0.9) based on `isHovered`,
  with a short ColorAnimation. `Config.toastBackground` = `withAlpha(background,
  0.9)`.
- **Close (✕) button**: top-right of the card (18x18, rounded, hover fills with
  `cardBackgroundHover`, glyph "✕"), calls `card.dismiss()`. The header text
  Column width now subtracts `closeBtn.width + 8`. Toast `dismiss()` is guarded
  by a `dismissing` flag (also stops the hide timer and prevents re-entry).
- User-tested: freeze works, opacity transitions 0.5→0.9 on hover, close dismisses.
- Layer rules (lines ~738-748): line 741 quickshell rule now has
  `animation = "slide right"` (+ blur + ignore_alpha 0.1). swaync-control-center
  rule (line 744) had the slide syntax. Line 746: dedicated `osd` namespace rule
  `blur = true, ignore_alpha = 0.1, animation = "slide bottom"` for the OSD
  overlay. `quickshell:overview`, `selection`
  rules exist. PanelWindow has NO `namespace` property in qmltypes (default
  namespace is `quickshell`) — `quickshell:overview` was pre-existing/unknown.
- Keybinds (lines 441-442):
  `mainMod + N` -> `quickshell ipc -c ricegueh call ricegueh toggleNotifications`
  `mainMod + M` -> `quickshell ipc -c ricegueh call ricegueh toggleQuickSettings`
  (mainMod = "SUPER"). These replaced the swaync-client bind.
- Autostart line 65: `hl.exec_cmd("swaync & waybar")` is now COMMENTED OUT.
- `hyprctl reload` to apply; reload returns "ok".

## IPC
- shell.qml has `IpcHandler { target: "ricegueh"; function toggleNotifications(): void;
  function toggleQuickSettings(): void }` toggling via ShellState.openNotifications/
  openQuickSettings(pointerScreen) or closeAll(). Verified with
  `quickshell ipc -c ricegueh call ricegueh toggleQuickSettings` + hyprctl layers.
- `function reload(): void { Quickshell.reload(false) }` added so matugen's
  post_hook can hot-reload: `quickshell ipc -c ricegueh call ricegueh reload`.

## MPRIS gotchas (player side)
- Firefox (music.youtube) reports Position 0 and no mpris:length in GetAll —
  harmless; quickshell computes position internally on read.
- playerctld keeps a permanent `org.mpris.MediaPlayer2.playerctld` bus name with
  NO track (GetAll errors `NoActivePlayer`) — its MprisPlayer must be excluded
  (no isPlaying, no trackTitle). Quickshell logs WARN lines for that GetAll;
  harmless.

## Open / possible next items
- Regular-window notifications: user was asked which app; user said "test later".
  If it recurs: likely an app bypassing the freedesktop daemon. (tracking fix
  should cover server-side untracked case.)
- User may want more modules / polish on any widget.
- Brightness responsiveness: OSD/bar lag the screen slightly (polling 300ms/2s
  vs event-driven volume). `brightnessctl monitor` exists but emits raw value
  only; user said "everything is done anyway" — not pursuing.
- matugen: `--prefer darkness` was needed when no terminal detected during our
  test run; the user's normal invocation (interactive/script) may not need it.
- Tray context menu now themed by a matugen kvantum theme. NOTE: user accepted
  that the menu doesn't perfectly match the quickshell panel (kvantum colors are
  generated from matugen: bg surface, text on_surface, highlight primary, so it
  IS rice-colored now, but the user said "it's ok anyway").

## Tray context menu (works)
- Tray.qml: per-delegate `QsMenuAnchor` (`menu: modelData.menu`,
  `anchor.item`, `edges: Edges.Top|Edges.Left`, `gravity: Edges.Bottom|Edges.Left`,
  `margins.left: 6`), right-click opens menu, middle = `secondaryActivate()`,
  left = `activate()` (Discord opens app); `onlyMenu` items open menu on left.
- REQUIRED `//@ pragma UseQApplication` as first line of shell.qml: platform
  menus (`PlatformMenuEntry`) qCritical without QApplication mode. Menu renders
  as a QtWidgets QMenu inside the quickshell process.

## Native menu theming (kvantum via matugen)
- The QMenu is a QtWidgets menu styled by the app's QStyle: quickshell inherits
  the global `QT_QPA_PLATFORMTHEME=qt5ct` -> `style=kvantum-dark` + custom
  palette `grey.conf`. No quickshell palette API exists.
- Fix scoped to ONLY quickshell: generate a kvantum theme from matugen and select
  it per-process.
  - `~/.config/matugen/config.toml` gained `[templates.kvantum]` (kvconfig ->
    `~/.config/Kvantum/matugen/matugen.kvconfig`) + `[templates.kvantum_svg]`
    (svg -> `~/.config/Kvantum/matugen/matugen.svg`). Template source:
    `/home/notfuad/builtbuiltdanclone/matugen-themes/templates/kvantum-colors.*`
    (symlinked as `~/.config/matugen/templates/`).
  - `//@ pragma Env KVANTUM_THEME = matugen` in shell.qml (instance pragma;
    verified the var IS set in-process via `Quickshell.env()`). Env pragmas are
    applied via qputenv in launch.cpp BEFORE QApplication creation, so the kvantum
    style reads it at construction. NOTE: `/proc/PID/environ` is stale after
    qputenv (glibc reallocs the env block) — verify with `Quickshell.env()` in QML
    instead.
  - Current palette was reproduced exactly from source color `#0bd790` with
    `matugen color hex "#0bd790" -m dark -t scheme-content` (from
    `--source_color` in `~/.config/gtk-4.0/colors.css`). The current wallpaper
    mountfujisubuh.jpeg is actually AVIF (misnamed) and undecodable by matugen.
  - kvantum theme is read at process start -> regenerate runs at next quickshell
    launch (mid-session matugen won't restyle the running menu).

## MPRIS max-duration bug (fixed)
- Symptom: after a track change (esp. while the detail popup was closed) the max
  duration label followed the current position until a manual pause/resume.
- Root cause (quickshell src/services/mpris/player.cpp): `MprisPlayer::length()`
  returns `position()` when metadata lacks `mpris:length` (`bLengthSupported`
  false). Some players (firefox/youtube) send metadata without `mpris:length` on
  track change; quickshell only re-reads metadata on PropertiesChanged, so length
  stayed bogus until the player re-sent metadata (pause/resume forces that).
- Fix (MprisDetail.qml): only trust `player.length` when it exceeds the position
  (`len > pos`), remember the last confirmed length, and reset it on
  `player.trackChanged` (Connections). `confirmedLength` updated inside the tick
  Timer (plain assignment, NOT inside a binding). Auto-heals as soon as the real
  length arrives; never shows a growing max. Timer runs even while the popup is
  hidden (PanelWindow only unmaps), so state stays fresh when closed.

## Relevant files
- shell.qml: NotificationServer, IpcHandler (incl. reload), bar/popup Variants,
  modulesHost, hoverBar, host wiring.
- widgets/Calendar.qml, NavButton.qml: calendar popup + nav button.
- widgets/ShellState.qml: shared state (barHover, barHoverTracker, dnd, popups,
  quickSettingsBottom, audioControlsBottom, calendarBottom, openNotifications/
  openQuickSettings/openCalendar/closeAll, addHistory/clearHistory,
  toastClearTick, osdVisible/osdScreen/osdType/osdLabel/osdOn/osdPercent/osdMuted).
- widgets/OsdMonitor.qml, Osd.qml: OSD drivers (locks/volume/brightness) + the
  OSD overlay window.
- widgets/ActionButton.qml: reusable notification action pill button.
- widgets/MirrorScreen.qml: quick-settings mirror-to-HDMI button (3 states via
  `hyprctl -j monitors all`, see Completed work).
- widgets/ToastCard.qml: freeze-on-hover hide timer (pause/resume, synchronous
  hover reads), 0.5→0.9 opacity on hover, close ✕ button, action + copy-code
  buttons.
- widgets/HoverHighlight.qml, ShellPopup.qml, ToggleRow.qml, QuickSettings.qml,
  NotificationCenter.qml, Toast.qml, ToastCard.qml, NotificationCard.qml,
  Mpris.qml, MprisDetail.qml, AudioControls.qml, VolumeGroup.qml, Orbit.qml,
  Battery.qml, Workspaces.qml, IdleInhibitor.qml, Config.qml, Swaync.qml, Clock.qml,
  Backlight.qml, Temperature.qml, Tray.qml, QuickAction.qml, TransportButton.qml,
  RotatedText.qml.
- matugen-colors.qml (generated, config root): the live palette; created from
  `~/.config/matugen/templates/quickshell-colors.qml` (in the matugen-themes repo)
  via `~/.config/matugen/config.toml` `[templates.quickshell]`.
- ~/.config/hypr/hyprland.lua: layer rules (741 quickshell, 746 osd), keybinds (441-442), autostart (65).