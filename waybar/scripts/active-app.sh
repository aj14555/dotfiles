#!/usr/bin/env bash
# Outputs the focused app's display name by looking up its .desktop file.
# Falls back to title-casing the WM class if no desktop file is found.

get_app_name() {
  local class="$1"
  [[ -z "$class" ]] && return

  # Search all desktop file dirs for a matching StartupWMClass
  local f
  f=$(grep -ril "StartupWMClass=${class}" \
    /usr/share/applications/ \
    ~/.local/share/applications/ \
    /var/lib/flatpak/exports/share/applications/ \
    ~/.local/share/flatpak/exports/share/applications/ \
    2>/dev/null | head -1)

  if [[ -n "$f" ]]; then
    grep "^Name=" "$f" | head -1 | cut -d= -f2
    return
  fi

  # Try matching desktop file by class name (case-insensitive)
  local lower="${class,,}"
  for dir in /usr/share/applications/ ~/.local/share/applications/ \
              /var/lib/flatpak/exports/share/applications/ \
              ~/.local/share/flatpak/exports/share/applications/; do
    f="${dir}${lower}.desktop"
    [[ -f "$f" ]] && { grep "^Name=" "$f" | head -1 | cut -d= -f2; return; }
  done

  # Fallback: title-case the class, strip common suffixes
  echo "$class" | sed 's/-/ /g; s/\b\(.\)/\u\1/g'
}

# Emit current state immediately on startup
class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')
get_app_name "$class"

# Subscribe to Hyprland events and re-emit on every focus change
socat - "UNIX-CONNECT:${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock" \
| while IFS= read -r line; do
  if [[ "$line" == activewindow* ]]; then
    class="${line#activewindow>>}"
    class="${class%%,*}"
    get_app_name "$class"
  fi
done
