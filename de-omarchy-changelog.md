# De-Omarchy Change Log

Running record of every change made during de-omarchification.
If something breaks, check the step and reverse the specific change listed.

---

## Step 1 — Freeze the scripts (detach from git)

**Status:** Done

### Commands run

```bash
git -C ~/.local/share/omarchy remote remove origin
```

### What changed

| What | Before | After |
|---|---|---|
| `~/.local/share/omarchy` git remote `origin` | `https://github.com/basecamp/omarchy.git` | Removed — no remotes |

### How to reverse

```bash
git -C ~/.local/share/omarchy remote add origin https://github.com/basecamp/omarchy.git
```

---

## Step 2 — Create system update script

**Status:** Done

### Files created

| File | Description |
|---|---|
| `~/.local/bin/system-update` | New personal update script (executable) |

### What the script does (mirrors omarchy update pipeline)

1. Prompts for confirmation (skip with `-y` flag)
2. Reinstalls `archlinux-keyring` to keep signing keys current
3. Runs `sudo pacman -Syyu --noconfirm` (full system upgrade)
4. Checks AUR availability via `curl`, then runs `yay -Sua --noconfirm --cleanafter`
5. Removes orphaned packages via `pacman -Qtdq`
6. Prompts to reboot if kernel or Hyprland was updated

### What was removed vs omarchy update

- Omarchy git pull step (`omarchy-update-git`) — not needed (we own the scripts now)
- `omarchy-keyring` package check — omarchy-specific, dropped
- `omarchy-snapshot create` — btrfs snapshot before update, omarchy-specific
- `omarchy-hook post-update` — omarchy hook system, dropped
- `omarchy-state` references — omarchy state dir, dropped
- `omarchy-system-reboot` wrapper — replaced with direct `systemctl reboot --no-wall`
- `omarchy-update-analyze-logs` — log analysis, dropped

### How to reverse

Delete the file:
```bash
rm ~/.local/bin/system-update
```

---

## Step 3 — Rename directories

**Status:** Done

### Directories renamed

| Old path | New path |
|---|---|
| `~/.local/share/omarchy/` | `~/.local/share/system/` |
| `~/.config/omarchy/` | `~/.config/desktop/` |
| `~/.local/state/omarchy/` | `~/.local/state/desktop/` |

### Files updated

| File | Old value | New value |
|---|---|---|
| `~/.bashrc` | `source ~/.local/share/omarchy/default/bash/rc` | `source ~/.local/share/system/default/bash/rc` |
| `~/.config/uwsm/env` | `export OMARCHY_PATH=$HOME/.local/share/omarchy` | `export OMARCHY_PATH=$HOME/.local/share/system` |
| `~/.local/share/system/default/bash/envs` | `export OMARCHY_PATH=$HOME/.local/share/omarchy` | `export OMARCHY_PATH=$HOME/.local/share/system` |
| `~/.config/hypr/hyprland.conf` | 9 source lines with `omarchy/default/hypr/` | Updated to `system/default/hypr/` |
| `~/.config/hypr/hyprland.conf` | `source = ~/.config/omarchy/current/theme/hyprland.conf` | `source = ~/.config/desktop/current/theme/hyprland.conf` |
| `~/.config/hypr/hyprland.conf` | `source = ~/.local/state/omarchy/toggles/hypr/*.conf` | `source = ~/.local/state/desktop/toggles/hypr/*.conf` |
| `~/.local/share/system/default/hypr/windows.conf` | `source = ~/.local/share/omarchy/default/hypr/apps.conf` | `source = ~/.local/share/system/default/hypr/apps.conf` |
| `~/.local/share/system/default/hypr/apps.conf` | 13 source lines with `omarchy/default/hypr/apps/` | Updated to `system/default/hypr/apps/` |
| `~/.local/share/system/default/hypr/envs.conf` | `source = ~/.config/omarchy/current/theme/gum.env.conf` | `source = ~/.config/desktop/current/theme/gum.env.conf` |
| `~/.local/share/system/default/hypr/autostart.conf` | `swaybg -i ~/.config/omarchy/current/background` | `swaybg -i ~/.config/desktop/current/background` |
| `~/.local/share/system/default/hypr/bindings.conf` | 3 source lines with `omarchy/default/hypr/` | Updated to `system/default/hypr/` |

### How to reverse

```bash
mv ~/.local/share/system ~/.local/share/omarchy
mv ~/.config/desktop ~/.config/omarchy
mv ~/.local/state/desktop ~/.local/state/omarchy
```

Then revert all file changes above (swap old/new values back).

---

## Step 4 — Absorb bash shell setup

**Status:** Done

### Files created

| File | Source |
|---|---|
| `~/.config/bash/rc` | New entry point (replaces system default, paths updated) |
| `~/.config/bash/envs` | Copied from `~/.local/share/system/default/bash/envs` |
| `~/.config/bash/shell` | Copied from `~/.local/share/system/default/bash/shell` |
| `~/.config/bash/aliases` | Copied from `~/.local/share/system/default/bash/aliases` |
| `~/.config/bash/functions` | Copied from `~/.local/share/system/default/bash/functions` (path updated) |
| `~/.config/bash/init` | Copied from `~/.local/share/system/default/bash/init` (path updated) |
| `~/.config/bash/inputrc` | Copied from `~/.local/share/system/default/bash/inputrc` |
| `~/.config/bash/completions` | Copied from `~/.local/share/system/default/bash/completions` |
| `~/.config/bash/fns/compression` | Copied from system default |
| `~/.config/bash/fns/drives` | Copied from system default |
| `~/.config/bash/fns/ssh-port-forwarding` | Copied from system default |
| `~/.config/bash/fns/tmux` | Copied from system default |
| `~/.config/bash/fns/transcoding` | Copied from system default |
| `~/.config/bash/fns/worktrees` | Copied from system default |

### Internal path changes made in copied files

| File | Old value | New value |
|---|---|---|
| `~/.config/bash/rc` | All sources pointed to `~/.local/share/system/default/bash/` | Now points to `~/.config/bash/` |
| `~/.config/bash/functions` | `for f in $OMARCHY_PATH/default/bash/fns/*` | `for f in ~/.config/bash/fns/*` |
| `~/.config/bash/init` | `source "$OMARCHY_PATH/default/bash/completions"` | `source ~/.config/bash/completions` |

### Files updated

| File | Old value | New value |
|---|---|---|
| `~/.bashrc` | `source ~/.local/share/system/default/bash/rc` | `source ~/.config/bash/rc` |

### How to reverse

```bash
rm -rf ~/.config/bash/
# Revert ~/.bashrc
# Change: source ~/.config/bash/rc
# Back to: source ~/.local/share/system/default/bash/rc
```

---

## Step 5 — Absorb Hyprland defaults

**Status:** Done

### Directory created

`~/.config/hypr/defaults/` — full copy of `~/.local/share/system/default/hypr/`

Contents:
- `autostart.conf`, `envs.conf`, `looknfeel.conf`, `input.conf`, `windows.conf`, `apps.conf`
- `bindings/` — `media.conf`, `clipboard.conf`, `tiling-v2.conf`, `tiling.conf`, `utilities.conf`
- `apps/` — 19 app-specific window rule configs
- `toggles/` — `flags.conf`, `single-window-aspect-ratio.conf`, `window-no-gaps.conf`
- `bindings.conf`, `plain-bindings.conf`

### Internal path changes (mass replacement)

All `~/.local/share/system/default/hypr/` references inside the copied files replaced with `~/.config/hypr/defaults/` (affected: `windows.conf`, `apps.conf`, `bindings.conf`)

### Files updated

| File | Old value | New value |
|---|---|---|
| `~/.config/hypr/hyprland.conf` | 9 source lines pointing to `~/.local/share/system/default/hypr/` | Now pointing to `~/.config/hypr/defaults/` |

### How to reverse

```bash
rm -rf ~/.config/hypr/defaults/
# Revert hyprland.conf source lines back to ~/.local/share/system/default/hypr/
```

---

## Step 6 — Update config path references

**Status:** Done

### Files updated (`~/.config/omarchy/` → `~/.config/desktop/`)

| File | What changed |
|---|---|
| `~/.config/hypr/hyprlock.conf` | `source = ~/.config/omarchy/current/theme/hyprlock.conf` → `desktop` |
| `~/.config/hypr/hyprlock.conf` | `path = ~/.config/omarchy/current/background` → `desktop` |
| `~/.config/waybar/style.css` | `@import "../omarchy/current/theme/waybar.css"` → `desktop` |
| `~/.config/walker/themes/omarchy-custom/style.css` | `@import ".../.config/omarchy/current/theme/walker.css"` → `desktop` |
| `~/.config/alacritty/alacritty.toml` | `general.import` path → `desktop` |
| `~/.config/foot/foot.ini` | `include=` path → `desktop` |
| `~/.config/ghostty/config` | `config-file` path → `desktop` |
| `~/.config/kitty/kitty.conf` | `include` path → `desktop` |
| `~/.config/desktop/hooks/theme-set.d/yazi-theme` | `COLORS=` path → `desktop` |
| `~/.config/desktop/starship/rainbow.toml` | Comment updated (no functional change) |

### Env vars renamed

| File | Old | New |
|---|---|---|
| `~/.config/uwsm/default` | `OMARCHY_SCREENSHOT_DIR` | `SCREENSHOT_DIR` |
| `~/.config/uwsm/default` | `OMARCHY_SCREENRECORD_DIR` | `SCREENRECORD_DIR` |
| `~/.local/share/system/bin/omarchy-capture-screenshot` | `${OMARCHY_SCREENSHOT_DIR:-...}` | `${SCREENSHOT_DIR:-...}` |
| `~/.local/share/system/bin/omarchy-capture-screenrecording` | `${OMARCHY_SCREENRECORD_DIR:-...}` | `${SCREENRECORD_DIR:-...}` |

### Intentionally skipped

- `~/.config/Cursor/User/History/` — Cursor IDE editor history files, not active configs
- `~/.config/fastfetch/config.jsonc` — handled in Step 7 (branding replacement)

### How to reverse

Swap all `desktop` back to `omarchy` and `SCREENSHOT_DIR` back to `OMARCHY_SCREENSHOT_DIR` in the files above.

---

## Step 7 — Replace Fastfetch branding

**Status:** Done

### File updated: `~/.config/fastfetch/config.jsonc`

| What | Old | New |
|---|---|---|
| Logo source | `~/.config/omarchy/branding/about.txt` (omarchy box logo) | `~/.config/desktop/branding/arch-logo.txt` (Arch Linux logo) |
| Logo color | `green` | `blue` |
| OS row | `command` → `omarchy-version` → "Omarchy 3.8.2" | Native `os` module → "Arch Linux x86_64" |
| Branch row | `command` → `omarchy-version-branch` → "main" | `command` → `pacman -Q linux \| awk '{print $2}'` → kernel pkg version |
| Channel row | `command` → `omarchy-version-channel` → "stable" | `command` → `uname -m` → architecture |
| Theme row | `command` → `omarchy-theme-current` | `command` → direct `cat ~/.config/desktop/current/theme.name` with same formatting |
| Update row | `command` → `omarchy-version-pkgs` | `command` → inline `date -d "$(grep upgraded /var/log/pacman.log …)"` (same logic, no wrapper) |

### How to reverse

Restore the original `~/.config/fastfetch/config.jsonc` from the plan or git history.

---

## Step 8 — Rename Waybar omarchy widget

**Status:** Done

### Files created

| File | Description |
|---|---|
| `~/.local/bin/check-updates` | Replaces `omarchy-update-available`; checks pacman + AUR for updates; exits 0 if updates found |

### `~/.config/waybar/config.jsonc` changes

| What | Old | New |
|---|---|---|
| Modules list | `"custom/omarchy"` | `"custom/menu"` |
| Widget definition key | `"custom/omarchy": {` | `"custom/menu": {` |
| Update exec | `"exec": "omarchy-update-available"` | `"exec": "check-updates"` |
| Update on-click | `omarchy-launch-floating-terminal-with-presentation omarchy-update` | `omarchy-launch-floating-terminal-with-presentation system-update` |
| Update tooltip | `"Omarchy update available"` | `"System update available"` |

### `~/.config/waybar/style.css` changes

| What | Old | New |
|---|---|---|
| CSS selector | `#custom-omarchy` | `#custom-menu` |
| CSS hover selector | `#custom-omarchy:hover` | `#custom-menu:hover` |
| Comment | `used by omarchy indicators` | `used by status indicators` |

### Note

Remaining `omarchy-*` script calls in `config.jsonc` (e.g. `omarchy-menu`, `omarchy-launch-bluetooth`) are functional scripts that still work — not branding.

### How to reverse

- Delete `~/.local/bin/check-updates`
- Revert widget name, exec, CSS class back to `omarchy` variants
- Restart waybar

---

## Step 9 — Rename Walker theme

**Status:** Done

### Directory renamed

| Old | New |
|---|---|
| `~/.config/walker/themes/omarchy-custom/` | `~/.config/walker/themes/my-theme/` |

### Symlink replaced

`~/.config/walker/themes/omarchy-custom/layout.xml` was a symlink to `~/.local/share/omarchy/default/walker/themes/omarchy-default/layout.xml` (broken after directory rename). Replaced with a real copy of the file from `~/.local/share/system/default/walker/themes/omarchy-default/layout.xml`.

### `~/.config/walker/config.toml` changes

| What | Old | New |
|---|---|---|
| Theme name | `theme = "omarchy-custom"` | `theme = "my-theme"` |
| Additional theme location | `additional_theme_location = "~/.local/share/omarchy/default/walker/themes/"` | Removed (no longer needed) |
| Restart command | `command = "omarchy-restart-walker"` | `command = "pkill walker; walker"` |

### How to reverse

```bash
mv ~/.config/walker/themes/my-theme ~/.config/walker/themes/omarchy-custom
```
Then revert `config.toml` changes and restart walker.

---

## Step 10 — Handle org.omarchy.about window rule

**Status:** Intentionally skipped

### Decision

Left `org.omarchy.about` as-is in `~/.config/hypr/looknfeel.conf` and the corresponding `.desktop` file in `~/.local/share/system/applications/`.

### Reasoning

- The app-id is an internal Wayland/GTK identifier — never visible to the user in normal use
- Only appears if you run `hyprctl clients` or read the config
- Renaming would require modifying the `.desktop` file, the window rule, and verifying the about screen still floats/centers/sizes correctly
- Risk outweighs the benefit for a purely cosmetic internal identifier

### Known remaining reference

`~/.config/hypr/looknfeel.conf` window rule: `match:class org.omarchy.about`

---

## Step 11 — Dotfiles repo tracking

**Status:** Done

### `~/dotfiles/sync` changes

| What | Old | New |
|---|---|---|
| Script header comment | "Sync Omarchy customizations" | "Sync desktop configs" |
| `usage()` description | "sync Omarchy configs to dotfiles" | "sync desktop configs to dotfiles" |
| Variable name | `OMARCHY_MAPPINGS` | `DESKTOP_MAPPINGS` |
| Source paths | `omarchy/hooks/`, `omarchy/themes/`, etc. | `desktop/hooks/`, `desktop/themes/`, etc. |
| New mapping added | — | `"bash/:bash/"` |
| Loop reference | `"${OMARCHY_MAPPINGS[@]}"` | `"${DESKTOP_MAPPINGS[@]}"` |

### New paths now tracked in dotfiles

| Path | Description |
|---|---|
| `~/dotfiles/bash/` | Absorbed bash shell setup (envs, aliases, functions, fns/, etc.) |
| `~/dotfiles/hypr/defaults/` | Absorbed Hyprland default configs |
| `~/dotfiles/walker/themes/my-theme/` | Renamed walker theme |
| `~/dotfiles/de-omarchy-plan.md` | This migration plan |
| `~/dotfiles/de-omarchy-changelog.md` | This change log |

### Paths removed from dotfiles

| Path | Reason |
|---|---|
| `~/dotfiles/walker/themes/omarchy-custom/` | Renamed to `my-theme` |

---

## Step 12 — Verify and clean up

**Status:** Done

### Issues found and fixed

| File | Issue | Fix |
|---|---|---|
| `~/.config/desktop/current/background` | Symlink still pointed to `~/.config/omarchy/backgrounds/...` (broken) | Re-created symlink to `~/.config/desktop/backgrounds/default-dark/Another World.jpg` |
| `~/.config/desktop/current/theme/mako.ini` | `include=~/.local/share/omarchy/default/mako/core.ini` | Updated to `system` path |
| `~/.config/desktop/themed/mako.ini.tpl` | Same stale path | Updated to `system` path |
| `~/.config/chromium-flags.conf` | `--load-extension=~/.local/share/omarchy/...` | Updated to `system` path |
| `~/.config/brave-flags.conf` | Same | Updated to `system` path |
| `~/.config/chrome-flags.conf` | Same | Updated to `system` path |
| `~/.config/systemd/user/omarchy-battery-monitor.service` | `ExecStart=%h/.local/share/omarchy/bin/...` | Updated to `system` path, daemon reloaded |
| `~/.config/systemd/user/omarchy-recover-internal-monitor.service` | Same | Updated to `system` path, daemon reloaded |

### Comments cleaned up

| File | Change |
|---|---|
| `~/.config/desktop/hooks/theme-set.d/cursor-theme` | Removed "Omarchy" from comments |
| `~/.config/desktop/hooks/theme-set.d/yazi-theme` | Removed "omarchy theme set" from comments |
| `~/.config/desktop/extensions/menu.sh` | Updated warning comment |
| `~/.config/waybar/fonts.preserve` | Removed "omarchy menu" from comment |

### Verified working

| Check | Result |
|---|---|
| `hyprctl configerrors` | Clean — no errors |
| `fastfetch` | Runs correctly with Arch logo |
| Bash functions (`ls`, `z`, `tdl`) | Load correctly in new shells |
| `which check-updates` | `/home/akila/.local/bin/check-updates` |
| `which system-update` | `/home/akila/.local/bin/system-update` |
| `~/.config/desktop/current/background` symlink | Points to correct `desktop` path |
| Waybar | Restarted cleanly |
| Walker | Restarted cleanly with `my-theme` |

### Intentionally remaining (not broken)

- `omarchy-*` script call names throughout configs — scripts still work from `~/.local/share/system/bin/`
- `OMARCHY_PATH` variable name — functional, scripts depend on it
- `org.omarchy.about` window class — internal app-id, intentional skip (Step 10)
- Cursor IDE chat history databases — binary files, not active configs
- Firefox `places.sqlite` — browser history, not active config
