---
name: omarchy-style
description: Apply and maintain the established visual style for this Omarchy system. Use when customizing waybar, walker, hyprland look and feel, fonts, blur, rounding, or any UI appearance. Ensures new changes match the current glassy/blur aesthetic with Inter Variable font and pill-shaped surfaces. Always use alongside the /omarchy skill.
---

# Omarchy Style System

This skill captures the visual design system established on this system.
**Always read the `/omarchy` skill first** for config file locations, safety rules, and apply commands.

## Core Design Tokens

| Token | Value | Where used |
|---|---|---|
| Background alpha | `alpha(@background, 0.60)` | Waybar, Walker surfaces |
| Border radius (bar/panels) | `12px` waybar · `16px` walker | Pill-shaped containers |
| Border | `1px solid alpha(@border, 0.18)` | Walker box |
| UI font | `'Inter Variable', 'CaskaydiaMono Nerd Font', sans-serif` | Waybar, Walker |
| Terminal/icon font | `'CaskaydiaMono Nerd Font'` | Terminals only |
| Window rounding | `rounding = 12` | Hyprland `looknfeel.conf` |

## Hyprland Windows

Settings live in `~/.config/hypr/looknfeel.conf`:

```
decoration {
    rounding = 12
    blur {
        enabled = true
        size = 8
        passes = 3
        noise = 0.02
        contrast = 0.9
        brightness = 0.8
        vibrancy = 0.15
        new_optimizations = true
    }
    shadow { range = 20; render_power = 3; color = rgba(00000066) }
    dim_inactive = true
    dim_strength = 0.1
}
```

After editing, validate: `hyprctl reload && hyprctl configerrors`

## Layer Blur (Waybar & Walker)

Declared in `~/.config/hypr/hyprland.conf` (Hyprland 0.53+ syntax):

```
layerrule = blur on, ignore_alpha 0, match:namespace waybar
layerrule = blur on, ignore_alpha 0, match:namespace walker
```

This applies the same blur pipeline as windows. The CSS background alpha controls
how much blur shows through — lower alpha = more blur visible.

## Waybar

### Layout (`~/.config/waybar/config.jsonc`)

```
modules-left:   custom/omarchy · hyprland/workspaces · clock
modules-center: mpris
modules-right:  custom/weather · custom/update · custom/voxtype ·
                indicators · group/tray-expander · bluetooth ·
                network · pulseaudio · cpu · battery
```

Bar floats with `"margin-top": 6, "margin-left": 8, "margin-right": 8`.

### Style (`~/.config/waybar/style.css`)

```css
/* Single unified pill — one background for the whole bar */
window#waybar {
  background: alpha(@background, 0.60);
  border-radius: 12px;
}

/* Font stack — Inter for text, Nerd Font fallback for icons */
* {
  font-family: 'Inter Variable', 'CaskaydiaMono Nerd Font', sans-serif;
  font-size: 13px;
}

/* Uniform icon size on right side */
.modules-right * { font-size: 14px; }

/* Right-side icon spacing: ~10px margin each side */
#bluetooth, #network, #pulseaudio, #cpu { margin: 0 10px; }
```

Always apply: `omarchy restart waybar`

## Walker

### Theme CSS (`~/.config/walker/themes/omarchy-custom/style.css`)

```css
* {
  font-family: 'Inter Variable', 'CaskaydiaMono Nerd Font', sans-serif;
  font-size: 15px;
}

.box-wrapper {
  background: alpha(@base, 0.60);
  border-radius: 16px;
  border: 1px solid alpha(@border, 0.18);
}

.search-container {
  background: alpha(@text, 0.06);
  border-radius: 10px;
}

child:selected { background: alpha(@selected-text, 0.15); }
```

Always apply: `omarchy restart walker`

### Icon–Label Gap Fix (Omarchy Menu)

The omarchy dmenu (`Super+Alt+Space`) renders icon glyphs and text as a single
string. `letter-spacing` spreads all characters — don't use it. Instead, an
extension in `~/.config/omarchy/extensions/menu.sh` overrides `menu()` to swap
the double-space separator for a Unicode em space (U+2003) before display, then
restores it on return so callers receive clean strings.

**Do not add `letter-spacing` to `.item-text`** — it breaks Inter's text rendering.

## Adding New Styled Components

When styling any new surface (rofi, mako, swaync, etc.):

1. Use `alpha(@background, 0.60)` for the background (matches other surfaces)
2. Use `border-radius: 12px` (bar-scale) or `16px` (panel-scale)
3. Add a `layerrule = blur on, ignore_alpha 0, match:namespace <name>` in `hyprland.conf`
4. Use the Inter/Nerd Font stack for text
5. Validate Hyprland: `hyprctl reload && hyprctl configerrors`

## Saving Changes

After any session of customization, run:

```bash
dots -c 'describe what you changed'   # sync + commit to ~/dotfiles
dots -p 'describe what you changed'   # sync + commit + push to GitHub
```

`dots` is a symlink at `~/.local/bin/dots` → `~/dotfiles/sync`. It tracks:
`~/.config/hypr/`, `waybar/`, `walker/`, `omarchy/hooks/`, `omarchy/themes/`,
`ghostty/`, `btop/`, `lazygit/`, `starship.toml`, `git/config`.

## What NOT to Change

- Do not edit `~/.local/share/omarchy/` — overwritten on `omarchy update`
- Do not add `letter-spacing` to walker item text (breaks Inter rendering)
- Do not use separate island pills per waybar section — single unified pill only
- Do not change terminal fonts away from `CaskaydiaMono Nerd Font`
