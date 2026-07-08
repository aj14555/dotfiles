# Overwrite parts of the omarchy-menu with user-specific submenus.
# See $OMARCHY_PATH/bin/omarchy-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will not be updated when the system menu changes.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) omarchy-system-lock ;;
#   *Shutdown*) omarchy-system-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
#
# Example of overriding just the about menu action: (Using zsh instead of bash (default))
#
show_about() {
  exec omarchy-launch-or-focus org.omarchy.about \
      "uwsm-app -- xdg-terminal-exec --app-id=org.omarchy.about -e bash -c 'while [ \"\$(tput cols 2>/dev/null || echo 0)\" -lt 120 ]; do sleep 0.05; done; fastfetch; read -n 1 -s'"
}

# ── Icon spacing fix ──────────────────────────────────────────────────────────
# Override menu() to replace the double-space between icon glyph and label with
# an em space (U+2003, 1em wide) for display only. The return value is cleaned
# back to two regular spaces so callers receive the original text unchanged.
menu() {
  local prompt="$1"
  local options="$2"
  local extra="$3"
  local preselect="$4"

  # Em space (U+2003) as a UTF-8 byte sequence
  local EM=$'\xe2\x80\x83'

  read -r -a args <<<"$extra"

  if [[ -n $preselect ]]; then
    local index
    index=$(echo -e "$options" | grep -nxF "$preselect" | cut -d: -f1)
    [[ -n $index ]] && args+=("-c" "$index")
  fi

  # Expand escape sequences, replace first "  " per line with em space for display
  local transformed
  transformed=$(echo -e "$options" | sed "s/  /${EM}/")

  # Run walker, capture result, then restore em space → two spaces for callers
  local result
  result=$(echo "$transformed" | omarchy-launch-walker --dmenu --width 295 --minheight 1 --maxheight 630 -p "$prompt…" "${args[@]}" 2>/dev/null)

  echo "${result//${EM}/  }"
}
