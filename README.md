# Custom Quickshell + Hyprland Setup — Progress & Next Steps

## Context
Daily driver: Arch Linux + Hyprland (Wayland), base config from JaKooLit's Arch-Hyprland
dotfiles. Was previously running Caelestia (quickshell-based shell) on top, but disliked
its Material UI theme and the overloaded launcher (app launch + `>` commands mixed
together). Decided to build a custom quickshell setup from scratch instead, using
Catppuccin Mocha as the palette. Comfortable in QML at this point.

Each component is a **separate quickshell instance** (own folder under
`~/.config/quickshell/`, own `shell.qml`), launched via `exec-once = qs -p <full path>`
in `~/.config/hypr/configs/Startup_Apps.conf`, and toggled (where relevant) via
`qs -p <path> ipc call <target> <function>` bound to a Hyprland keybind in
`~/.config/hypr/configs/Keybinds.conf`.

---

## ✅ Done

### 1. Bar — `~/.config/quickshell/shell.qml`
- Transparent `PanelWindow` (no solid background) — each element is its own floating
  pill `Rectangle`, so only the widgets are visible, not a solid bar strip
- **Workspaces** — Hyprland IPC (`Hyprland.workspaces`), filtered to exclude special/
  scratchpad workspaces (negative IDs), active workspace highlighted
- **Active window title** — `Hyprland.activeToplevel.title`, elided
- **Clock** — `SystemClock`, `hh:mm:ss`, center pill
- **Date** — `ddd MMM d`, right side
- **System tray** — `SystemTray.items`, click to activate
- **Volume** — Pipewire (`Pipewire.defaultAudioSink`, requires `PwObjectTracker` to
  actually get live updates — this was a real bug we hit). Click pill to toggle mute.
- **Battery** — UPower, icon scales through charge-level bands (not just 2-state)
- **Wifi** — polled via `nmcli` through `Quickshell.Io.Process` (no native Quickshell
  network service used). Click pill → popup listing nearby networks (via a second
  on-demand `nmcli` scan), click a network to `nmcli dev wifi connect`. Does **not**
  yet handle entering a password for new secured networks — only works for
  already-known/saved or open networks.
- Catppuccin Mocha palette defined as named `readonly property color` values on the
  `PanelWindow`, reused everywhere.

### 2. App Launcher — `~/.config/quickshell/launcher/shell.qml`
- Keybind: `SUPER+D`
- Rofi-style: centered search box + filtered list, arrow keys + Enter, Esc to close
- Parses `.desktop` files from `/usr/share/applications` and `~/.local/share/applications`
  via a shell `Process` (blunt scan — doesn't handle `Actions=`, quoted `Exec=` args
  with spaces, or the full XDG spec)
- Runs hidden in background at all times (`visible: false`), toggled via
  `IpcHandler { target: "launcher" }` — instant open, no cold start
- Deliberately **app-launching only** — no `>` command mode (that functionality was
  intentionally split out into the wallpaper switcher instead)

### 3. Wallpaper Switcher — `~/.config/quickshell/wallpaper/shell.qml`
- Keybind: `SUPER+W`
- Wallpaper source dir: `~/Pictures/Wallpapers`
- Centered popup, single row of 4 large thumbnails (not a grid), search bar to filter
  by filename, arrow keys + Enter + click to select, Esc to close
- Applies wallpaper via **`swww`** (`swww img ... --transition-type grow`) —
  `swww-daemon --format xrgb` added to `Startup_Apps.conf`. Note: on this system the
  installed package was `awww` (a fork/rename), but `swww`/`swww-daemon` exist as
  working compat binaries, so no command changes were needed.
- Uses a `FocusScope` wrapping the content so Esc (on the scope) and arrow-key nav
  (on the search field / grid) both work correctly without stealing each other's focus

### 4. Notifications — `~/.config/quickshell/notifications/shell.qml`
- No keybind — runs invisibly, reacts to any app sending a D-Bus notification via
  Quickshell's `NotificationServer` (`org.freedesktop.Notifications`)
- Transient popups only (no history panel, by choice) — bottom-right corner, stack
  vertically, auto-dismiss after 5s via a dynamically created `Timer`, click to
  dismiss early
- Background is semi-transparent (`Qt.rgba(...)` low alpha) + a Hyprland
  `layerrule = blur, ...` for genuine frosted-glass blur (QML alone can't blur what's
  behind it — needed the compositor's help)
- Confirmed no conflicting notification daemon (swaync) is running/autostarting

### 5. Cleanup (Caelestia + unused JaKooLit-installed app configs removed)
Removed:
- `~/.config/quickshell/{caelestia,overview,modules,services}/` and
  `config.json`, `GlobalStates.qml`, `qml_color.json` at the quickshell root
  (all confirmed unused by the 4 custom instances via grep before deletion)
- `~/.config/{rofi,swaync,waybar,wlogout}` and their `-backup-back-up_0814_1935` dirs
  (unused — replaced by the custom launcher/notifications/bar; nothing referenced
  `wlogout` in keybinds either, confirmed before deleting)
- Dead Caelestia keybinds in `Keybinds.conf`: drawers toggle (dashboard, sidebar,
  utilities, session, bar), MPRIS playPause/next/previous, picker open
- Commented-out `exec-once = qs -c caelestia` line in `Startup_Apps.conf`

Kept as-is (not touched, still working):
- JaKooLit's core Hyprland config structure (window rules, animations, decorations,
  base keybind set, scripts dir)
- `LockScreen.sh` and its keybind — lock screen is untouched/still functional

---

## ⏳ Known gaps / not yet built

These were features Caelestia provided that don't have a replacement yet. None are
currently bound to a key (the old binds were deleted, not repointed):

1. **Screenshot / color picker** (`SUPER SHIFT+S` originally) — was Caelestia's
   `picker open`. Straightforward to rebuild with `grim` + `slurp` (+ maybe `hyprpicker`
   for the color-picker half). Flagged as high-value / quick to do, just not done yet.

2. **Session menu** (`SUPER+Escape` originally) — lock/logout/reboot/shutdown UI.
   Note: the actual *lock* functionality (`LockScreen.sh`) is separate and still works;
   this gap is specifically the visual session-choice menu, not being locked out.

3. **Dashboard** (`SUPER+Space` originally) — Caelestia's home/overview-style panel.
   Not scoped yet — no clear spec for what should be on it.

4. **Sidebar** (`SUPER+N` originally) — likely notifications-history / media-focused
   in Caelestia. Given the notification daemon here is transient-only by choice, a
   sidebar could be where a future "notification history" would live if that's ever
   wanted (currently explicitly out of scope — "transient popups for now").

5. **Utilities / Control Center** (`SUPER+U` originally) — inferred (not confirmed
   from actual source, since the local Caelestia install was deleted before checking)
   to correspond to Caelestia's `controlcenter` module: likely quick toggles (wifi/
   bluetooth/DND/night light), brightness/volume sliders. Not scoped or built.

None of these are urgent — explicitly deprioritized in favor of getting the working
core (bar, launcher, wallpaper, notifications) solid and cleaned up first.

---

## 🗺️ Next planned step: Git + reflash prep

Goal: push the whole custom config to a git repo so that reflashing Arch becomes
"clone repo, symlink/copy dotfiles" instead of rebuilding from memory.

Not yet done — still needs figuring out:
- What repo scope makes sense (just `~/.config/quickshell/*` + the Hyprland config
  diffs, vs. a fuller dotfiles repo)
- Whether to strip machine-specific absolute paths (e.g. `/home/aditya/...` hardcoded
  in several `exec-once` and `ipc call` lines) in favor of something portable, or leave
  them as-is since it's a personal single-machine setup
- `.gitignore` needs for anything generated/cache-like in the quickshell dirs
- Whether JaKooLit's base config should be tracked wholesale in the same repo, tracked
  separately, or just re-run via their installer on a fresh Arch install and only the
  custom quickshell bits + config *diffs* layered on top from this repo

---

## Useful reference commands (debugging patterns established during this build)

```bash
# Check what's actually running under a given quickshell config name
ps aux | grep "qs -c <name>"

# Foreground-run a quickshell config to see errors live (does NOT reliably work with
# -c <name> on this system — "-c" folder-name resolution was flaky/cached; -p with a
# full path was the reliable method throughout)
qs -p ~/.config/quickshell/<name>/shell.qml

# Toggle a running instance via IPC (needs the SAME -p path used to launch it, and a
# short delay after launch — IPC calls fired immediately after backgrounding a launch
# can race the instance still registering)
qs -p ~/.config/quickshell/<name>/shell.qml ipc call <target> <function>

# List active Hyprland layer-shell surfaces + their exact namespace (useful for
# targeting layerrule = blur, <namespace> correctly)
hyprctl layers
```
