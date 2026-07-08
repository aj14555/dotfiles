# De-Omarchy Plan

Remove all "omarchy" from the system while keeping the exact current state and workflow.

## Layer Map

| Layer | Current | Target |
|---|---|---|
| Scripts dir | `~/.local/share/omarchy/bin/` (git-managed) | Detach git, rename dir to `~/.local/share/system/` |
| User config | `~/.config/omarchy/` | Rename to `~/.config/desktop/` |
| State/toggles | `~/.local/state/omarchy/` | Rename to `~/.local/state/desktop/` |
| Bash shell | Sourced from omarchy default dir | Copy files into your dotfiles |
| Hyprland | Sources 8 files from omarchy default dir | Copy files into `~/.config/hypr/` |
| Fastfetch | Omarchy logo + version/branch/channel | Arch Linux logo + kernel/OS info |
| Waybar | `custom/omarchy` widget + update widget | Rename widget, replace update command |
| Walker | Theme `omarchy-custom`, omarchy theme path | Rename theme, copy theme dir |

---

## Step 1 — Freeze the scripts (detach from git)

Remove the upstream git remote from `~/.local/share/omarchy/` so `omarchy update` can never pull changes and overwrite customizations. The scripts stay in place and keep working.

```bash
git -C ~/.local/share/omarchy remote remove origin
```

---

## Step 2 — Create your own system update script

Replace the functionality of `omarchy update` with a script you own at `~/.local/bin/system-update`. It should:
1. Update the Arch keyring
2. Run `sudo pacman -Syu`
3. Run `paru -Sua` (AUR packages)
4. Optionally notify/restart waybar

Wire this as the waybar update button (replaces the `omarchy-update` exec in `config.jsonc`).

---

## Step 3 — Rename the directories

Three renames + update env var references in 2 places:

```bash
mv ~/.local/share/omarchy ~/.local/share/system
mv ~/.config/omarchy     ~/.config/desktop
mv ~/.local/state/omarchy ~/.local/state/desktop
```

Then update `OMARCHY_PATH` (and its name) in:
- `~/.config/uwsm/env` — change to `DESKTOP_PATH=$HOME/.local/share/system`
- The bash envs file you'll absorb in Step 4 — same change

Scripts that use `$OMARCHY_PATH` internally (33 of 283) will just pick it up from the new env var name.

---

## Step 4 — Absorb the bash shell setup into your dotfiles

Currently `~/.bashrc` sources `~/.local/share/omarchy/default/bash/rc`, which chains into envs, shell, aliases, functions, init, inputrc, completions, and `fns/`. Copy all these files into `~/.config/bash/` in your dotfiles, then update `~/.bashrc` to source from there. You own the files, they're in your dotfiles repo, and the renamed `DESKTOP_PATH` lives here.

Files to copy:
- `default/bash/{envs,shell,aliases,functions,init,inputrc,completions}`
- `default/bash/fns/` directory (5 function files: compression, drives, ssh-port-forwarding, tmux, transcoding, worktrees)

---

## Step 5 — Absorb the Hyprland default sources

`~/.config/hypr/hyprland.conf` sources 8 files from the omarchy dir:

```
~/.local/share/omarchy/default/hypr/autostart.conf
~/.local/share/omarchy/default/hypr/bindings/media.conf
~/.local/share/omarchy/default/hypr/bindings/clipboard.conf
~/.local/share/omarchy/default/hypr/bindings/tiling-v2.conf
~/.local/share/omarchy/default/hypr/bindings/utilities.conf
~/.local/share/omarchy/default/hypr/envs.conf
~/.local/share/omarchy/default/hypr/looknfeel.conf
~/.local/share/omarchy/default/hypr/windows.conf
```

Copy all into `~/.config/hypr/defaults/`. Update `hyprland.conf` source paths. Also update the toggles source line from `~/.local/state/omarchy/toggles/hypr/` to `~/.local/state/desktop/toggles/hypr/`.

---

## Step 6 — Update all `~/.config/omarchy/` → `~/.config/desktop/` references

After Step 3's rename, these files need path updates:

| File | Reference to update |
|---|---|
| `~/.config/hypr/hyprland.conf` | `source = ~/.config/omarchy/current/theme/hyprland.conf` |
| `~/.config/hypr/hyprlock.conf` | `source = ~/.config/omarchy/current/theme/hyprlock.conf` and `path = ~/.config/omarchy/current/background` |
| `~/.config/waybar/style.css` | `@import "../omarchy/current/theme/waybar.css"` |
| `~/.config/walker/themes/omarchy-custom/style.css` | `@import "~/.config/omarchy/current/theme/walker.css"` |
| `~/.config/fastfetch/config.jsonc` | `source = "~/.config/omarchy/branding/about.txt"` |
| `~/.config/uwsm/default` | `OMARCHY_SCREENSHOT_DIR`, `OMARCHY_SCREENRECORD_DIR` → rename to `SCREENSHOT_DIR`, `SCREENRECORD_DIR` |

Also update the capture scripts (`omarchy-capture-screenshot`, `omarchy-capture-screenrecording`) in your system dir to read the renamed env vars.

---

## Step 7 — Replace Fastfetch branding

- Swap the logo source from `~/.config/desktop/branding/about.txt` (omarchy box logo) to `~/.config/desktop/branding/arch-logo.txt` (already present)
- Replace the 3 "Omarchy version/branch/channel" command modules with:
  - `os` module (shows `Arch Linux`)
  - A `pacman -Q linux` command for kernel package version
  - Last update date via `expac --timefmt='%Y-%m-%d' '%l' linux | sort -r | head -1`
- Keep the existing theme/font/WM modules (they don't need omarchy)

---

## Step 8 — Rename the Waybar omarchy widget

In `~/.config/waybar/config.jsonc`:
- Rename `"custom/omarchy"` → `"custom/menu"`
- Update the modules list reference

In `~/.config/waybar/style.css`:
- Rename `#custom-omarchy` → `#custom-menu`

The button still calls `omarchy-menu` (script still exists in system dir), so functionality is identical. Script can be renamed later if desired.

---

## Step 9 — Rename the Walker theme

```bash
mv ~/.config/walker/themes/omarchy-custom ~/.config/walker/themes/my-theme
```

Update `~/.config/walker/config.toml`:
- `theme = "my-theme"`
- `additional_theme_location = "~/.config/walker/themes/"` (or remove — theme is now directly in that dir)
- `command = "pkill walker; walker"` (direct restart, no omarchy-restart-walker wrapper needed)

---

## Step 10 — Handle `org.omarchy.about` window rule

`~/.config/hypr/looknfeel.conf` has a window rule for `org.omarchy.about` (the fastfetch about window launched from waybar). Options:
- **Leave it** — it still matches if the `.desktop` file still uses that app-id
- **Rename** — copy the `.desktop` from `~/.local/share/system/applications/` to `~/.local/share/applications/`, change `StartupWMClass` to `org.archlinux.about`, and update the window rule

---

## Step 11 — Dotfiles repo: track new paths

Add to git tracking:
- `~/.config/bash/` (absorbed bash setup)
- `~/.config/hypr/defaults/` (absorbed hypr defaults)
- `~/.config/desktop/` (renamed from omarchy config)

Remove stale `~/.config/omarchy/` references from dotfiles if tracked there.

---

## Step 12 — Verify and clean up

1. Log out and back in (UWSM picks up new env from `~/.config/uwsm/env`)
2. Check `echo $DESKTOP_PATH` in terminal — should show new path
3. Check `which omarchy-launch-browser` — should still resolve
4. Test waybar, walker, hyprlock all work
5. Once verified, `~/.local/share/system/` is just a frozen directory of scripts you own — nothing pulls from it anymore

---

## What stays the same

- All keybindings, themes, wallpapers, hyprland behavior
- All `omarchy-*` scripts continue to work (same scripts, same PATH)
- Theme switching still works (`~/.config/desktop/current/` symlink structure is identical)
- Walker, waybar, mako, hypridle all unchanged in behavior

## What genuinely disappears

- `omarchy update` (replaced by your own `system-update` script)
- Omarchy version/branch/channel in fastfetch
- Omarchy logo in fastfetch (replaced with arch-logo)
- `custom/omarchy` waybar widget name
- All file paths containing "omarchy"
- Git remote pointing to `basecamp/omarchy`
