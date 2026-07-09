# De-Omarchy: Scripts & Remaining Names Plan

System scan results after the initial de-omarchy pass. This covers everything still named "omarchy" — directories, scripts, service files, env vars, app-ids, and content references.

---

## Scan Summary

| Category | Count | Risk |
|---|---|---|
| Script names in `~/.local/share/system/bin/` | 282 | High |
| Systemd service/timer files | 3 | Low |
| Directories named omarchy | 6 | Low–Medium |
| `OMARCHY_PATH` env var (not yet renamed) | 1 | Low |
| Stale `~/.local/state/omarchy/` directory | 1 | Medium (state files live there) |
| Stale `~/.local/bin/walker/themes/omarchy-custom/` | 1 | Low (broken symlink) |
| `org.omarchy.*` app-id window rules | 8 | Low (internal only) |
| `_omarchy_complete()` in bash completions | 1 | Low |
| Comments/text referencing omarchy | ~15 files | Trivial |

---

## Part 1 — Broken/Stale items (fix now, low risk)

### 1a — `~/.local/state/omarchy/` still exists alongside `~/.local/state/desktop/`

**Problem:** Step 3 renamed the directory, but the old path still exists with live state files inside (`toggles/hypr/flags.conf`). More critically, the systemd service `omarchy-recover-internal-monitor.service` still checks:

```
ConditionPathExists=%h/.local/state/omarchy/toggles/hypr/internal-monitor-disable.conf
```

Hyprland reads toggles from `~/.local/state/desktop/toggles/hypr/` (updated in step 3), but the service checks the old path. This is an inconsistency.

**Fix:**
1. Migrate any state files from `~/.local/state/omarchy/` to `~/.local/state/desktop/` that aren't already there
2. Remove `~/.local/state/omarchy/` once confirmed empty or merged

```bash
# Check what's in the stale dir
ls ~/.local/state/omarchy/

# Merge (rsync preserves structure, no overwrite)
rsync -av --ignore-existing ~/.local/state/omarchy/ ~/.local/state/desktop/

# Confirm desktop has everything, then remove
rm -rf ~/.local/state/omarchy
```

---

### 1b — `~/.local/bin/walker/themes/omarchy-custom/` stale directory

**Problem:** This is a leftover from before step 9 renamed the theme. It contains a broken symlink:

```
layout.xml -> /home/akila/.local/share/omarchy/default/walker/themes/omarchy-default/layout.xml
```

The path `~/.local/share/omarchy/` no longer exists (renamed to `system/`). This directory serves no purpose — the live theme is at `~/.config/walker/themes/my-theme/`.

**Fix:**
```bash
rm -rf ~/.local/bin/walker/themes/omarchy-custom
```

---

### 1c — `OMARCHY_PATH` in `~/.config/uwsm/env` not renamed to `DESKTOP_PATH`

**Problem:** The original plan (Step 3) said to rename `OMARCHY_PATH` to `DESKTOP_PATH`, but the changelog shows only the path value was updated. The variable name still reads `OMARCHY_PATH`.

Current state of `~/.config/uwsm/env`:
```bash
export OMARCHY_PATH=$HOME/.local/share/system
```

**Problem:** All 282 scripts in `system/bin/` use `$OMARCHY_PATH` internally. Renaming the var means updating all 282 scripts **or** exporting both names as an alias. The safe approach is to export a compatibility shim and rename only the "public" name:

```bash
# In ~/.config/uwsm/env — replace the existing line:
export DESKTOP_PATH=$HOME/.local/share/system
export OMARCHY_PATH=$DESKTOP_PATH   # compatibility shim until scripts are renamed
```

This way the var name is de-branded at the env level, and the shim keeps the 282 scripts working without mass-editing them.

Also update the same definition in `~/.config/bash/envs`:
```bash
export DESKTOP_PATH=$HOME/.local/share/system
export OMARCHY_PATH=$DESKTOP_PATH
```

---

## Part 2 — Systemd service file renames (low risk)

Three systemd unit files are named `omarchy-*`:

| Current name | New name |
|---|---|
| `omarchy-battery-monitor.service` | `system-battery-monitor.service` |
| `omarchy-battery-monitor.timer` | `system-battery-monitor.timer` |
| `omarchy-recover-internal-monitor.service` | `system-recover-internal-monitor.service` |

Symlinks in `timers.target.wants/` and `graphical-session-pre.target.wants/` also need updating.

**Fix (do atomically):**
```bash
# Stop and disable old units
systemctl --user stop omarchy-battery-monitor.timer
systemctl --user disable omarchy-battery-monitor.timer
systemctl --user disable omarchy-recover-internal-monitor.service

# Rename the files
cd ~/.config/systemd/user/
mv omarchy-battery-monitor.service system-battery-monitor.service
mv omarchy-battery-monitor.timer    system-battery-monitor.timer
mv omarchy-recover-internal-monitor.service system-recover-internal-monitor.service

# Update the Description= line in the service files (cosmetic)
# sed -i 's/Omarchy Battery Monitor/System Battery Monitor/g' system-battery-monitor.service
# sed -i 's/ConditionPathExists=.*state\/omarchy\//ConditionPathExists=%h\/.local\/state\/desktop\//g' system-recover-internal-monitor.service

# Reload and re-enable
systemctl --user daemon-reload
systemctl --user enable --now system-battery-monitor.timer
systemctl --user enable system-recover-internal-monitor.service
```

Also update `ConditionPathExists` in `system-recover-internal-monitor.service`:
- Old: `%h/.local/state/omarchy/toggles/hypr/internal-monitor-disable.conf`
- New: `%h/.local/state/desktop/toggles/hypr/internal-monitor-disable.conf`

---

## Part 3 — Rename omarchy-named directories in `~/.local/share/system/`

Four directories inside `~/.local/share/system/` still carry the omarchy name:

| Current path | Suggested new path | Notes |
|---|---|---|
| `default/omarchy-skill/` | `default/system-skill/` | The Cursor agent SKILL.md for this system |
| `config/omarchy/` | `config/defaults/` | Default config templates (extensions, hooks, themed) |
| `default/sddm/omarchy/` | `default/sddm/minimal/` | SDDM login theme (also update `metadata.desktop` Name= field) |
| `default/walker/themes/omarchy-default/` | `default/walker/themes/system-default/` | Default walker layout |

**Fix:**
```bash
mv ~/.local/share/system/default/omarchy-skill ~/.local/share/system/default/system-skill
mv ~/.local/share/system/config/omarchy        ~/.local/share/system/config/defaults
mv ~/.local/share/system/default/sddm/omarchy  ~/.local/share/system/default/sddm/minimal
mv ~/.local/share/system/default/walker/themes/omarchy-default \
   ~/.local/share/system/default/walker/themes/system-default
```

After renaming `config/omarchy/` → `config/defaults/`, search for any scripts that reference `$OMARCHY_PATH/config/omarchy/` (there are a few in the install/reinstall scripts).

After renaming `sddm/omarchy/`, update `metadata.desktop`:
```ini
Name=Minimal
Author=System
```

After renaming `walker/themes/omarchy-default/`, check if any scripts reference `omarchy-default` by name (e.g., `omarchy-refresh-walker`).

---

## Part 4 — The 282 `omarchy-*` scripts (big rename, phased approach)

This is the largest remaining change. All 282 executables in `~/.local/share/system/bin/` are named `omarchy-*`. They are referenced from:

- `~/.config/waybar/config.jsonc` (at least 12 script calls)
- `~/.config/hypr/defaults/bindings/utilities.conf` (35+ exec lines)
- `~/.config/hypr/defaults/bindings/media.conf` (20+ exec lines)
- `~/.config/hypr/defaults/autostart.conf` (5 exec lines)
- `~/.config/hypr/bindings.conf` (personal bindings file)
- `~/.config/hypr/defaults/apps/system.conf` (window rules reference `org.omarchy.*` app-ids set by the scripts)
- Inside the scripts themselves (scripts call each other)

### Strategy: rename prefix `omarchy-` → `sys-`

New names use the `sys-` prefix. Examples:
- `omarchy-menu` → `sys-menu`
- `omarchy-theme-set` → `sys-theme-set`
- `omarchy-launch-browser` → `sys-launch-browser`
- `omarchy-capture-screenshot` → `sys-capture-screenshot`

**Phase 4a — Rename script files + create backward-compat symlinks**

This allows all existing config references to keep working while the real files are renamed. Symlinks can be removed later after all call sites are updated.

```bash
cd ~/.local/share/system/bin

for f in omarchy-*; do
  new="${f/omarchy-/sys-}"
  mv "$f" "$new"
  ln -s "$new" "$f"   # backward-compat symlink
done

# Also rename the bare `omarchy` script
mv omarchy sys
ln -s sys omarchy
```

After this step: `sys-menu` is the real binary, `omarchy-menu` is a symlink to it. Everything still works.

**Phase 4b — Update call sites in personal configs**

Update your owned config files to call `sys-*` instead of `omarchy-*`:

| File | Action |
|---|---|
| `~/.config/waybar/config.jsonc` | Replace `omarchy-*` exec commands |
| `~/.config/hypr/bindings.conf` | Replace `omarchy-*` exec commands |
| `~/.config/hypr/defaults/bindings/utilities.conf` | Replace all exec lines |
| `~/.config/hypr/defaults/bindings/media.conf` | Replace all exec lines |
| `~/.config/hypr/defaults/autostart.conf` | Replace all exec lines |
| `~/.config/desktop/extensions/menu.sh` | Replace script calls |
| `~/.config/bash/fns/transcoding` | Replace `omarchy-transcode` calls |

**Phase 4c — Update internal script cross-references**

Scripts call each other (e.g., `omarchy-menu` calls `omarchy-system-lock`). After the symlinks are in place this is not strictly necessary, but for cleanliness:

```bash
cd ~/.local/share/system/bin
# Replace all internal omarchy- references with sys-
for f in sys-*; do
  sed -i 's/omarchy-/sys-/g' "$f"
done
sed -i 's/omarchy-/sys-/g' sys
```

**Phase 4d — Remove backward-compat symlinks**

Once all call sites have been updated and verified:

```bash
cd ~/.local/share/system/bin
for f in omarchy-*; do
  [ -L "$f" ] && rm "$f"
done
[ -L omarchy ] && rm omarchy
```

---

## Part 5 — `_omarchy_complete()` in bash completions

`~/.config/bash/completions` has a shell completion function named `_omarchy_complete` that provides tab completion for `omarchy` and `omarchy-*` commands.

After Part 4, the entry point binary becomes `sys`. The completion function should be updated:

- Rename function to `_sys_complete()`
- Change `prefix="omarchy"` → `prefix="sys"`
- Change `complete ... omarchy` → `complete ... sys`
- Keep or remove the `# Hide individual omarchy-* binaries` comment (no longer needed after phase 4d)

---

## Part 6 — `org.omarchy.*` app-id window rules

These appear in `~/.config/hypr/defaults/apps/system.conf` and `looknfeel.conf`. They are internal Wayland app-ids set by the scripts themselves (e.g., `omarchy-launch-about` sets the app-id to `org.omarchy.about`).

**After Part 4:** When the scripts are renamed to `sys-*`, you can optionally update the app-ids they set to `org.system.*` or `org.local.*`. This requires editing the scripts themselves and the corresponding window rules.

Specific ones to consider:

| Script | App-id set | Window rule |
|---|---|---|
| `omarchy-launch-about` | `org.omarchy.about` | `looknfeel.conf` (size/float/center) |
| `omarchy-screensaver` | `org.omarchy.screensaver` | `apps/system.conf` (fullscreen) |
| `omarchy-launch-*-tui` | `org.omarchy.bluetui`, `org.omarchy.btop`, etc. | `apps/system.conf` (floating) |

**Recommendation:** Defer until after Part 4. The app-ids are purely internal and invisible during normal use. Tackle them as a cleanup pass after the script rename is stable.

---

## Part 7 — Comment/text cleanup

Minor cleanup in these files — no functional impact, but removes branding noise:

| File | Reference |
|---|---|
| `~/.config/desktop/extensions/menu.sh` | Comments mention `omarchy-menu` and `$OMARCHY_PATH` |
| `~/.config/bash/fns/transcoding` | Comment: "Transcoding helpers have moved to omarchy-transcode" |
| `~/.config/hypr/defaults/bindings/utilities.conf` | Keybinding descriptions "Omarchy menu" |
| `~/.config/hypr/defaults/apps/jetbrains.conf` | GitHub URL comment referencing `basecamp/omarchy` |
| `~/.local/share/system/default/omarchy-skill/SKILL.md` | Entire file is about Omarchy — update after renaming dir in Part 3 |

---

## Execution Order

| Step | Part | Effort | Risk |
|---|---|---|---|
| 1 | 1a — Merge `~/.local/state/omarchy/` → `~/.local/state/desktop/` | 5 min | Low |
| 2 | 1b — Remove stale `~/.local/bin/walker/themes/omarchy-custom/` | 1 min | None |
| 3 | 1c — Add `DESKTOP_PATH` + compat shim in uwsm/env and bash/envs | 5 min | Low |
| 4 | 2 — Rename 3 systemd service files | 10 min | Low |
| 5 | 3 — Rename 4 directories in `~/.local/share/system/` | 10 min | Low |
| 6 | 4a — Rename 282 scripts + add backward-compat symlinks | 2 min | None (symlinks cover it) |
| 7 | 4b — Update call sites in personal configs | 30 min | Medium |
| 8 | 5 — Update bash completions | 5 min | Low |
| 9 | 4c — Update internal script cross-references | 5 min (scripted) | Low |
| 10 | 4d — Remove backward-compat symlinks | 2 min | Low (verify first) |
| 11 | 6 — Update org.omarchy.* app-ids (optional) | 20 min | Medium |
| 12 | 7 — Comment cleanup | 10 min | None |

Steps 1–5 are safe and independent. Step 6 (script rename with symlinks) is the safest way to do the big rename without breaking anything. Steps 7–10 can be done incrementally as you verify each config.
