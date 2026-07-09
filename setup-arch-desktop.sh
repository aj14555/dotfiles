#!/usr/bin/env bash
# =============================================================================
# setup-arch-desktop.sh
# Bootstrap a Hyprland + Waybar + Walker desktop on a plain Arch Linux install.
# Replicates the look and behaviour of an Omarchy-based system without Omarchy.
#
# Run as your normal (non-root) user. sudo is called internally where needed.
# Usage: bash ~/setup-arch-desktop.sh
# =============================================================================
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
step()    { echo -e "\n${BOLD}══ $* ══${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CFG="$HOME/.config"
mkdir -p "$BIN_DIR"

# ── 1. PACKAGE INSTALLATION ──────────────────────────────────────────────────
step "Installing packages"

# Install yay if not present
if ! command -v yay &>/dev/null; then
    info "Installing yay AUR helper…"
    sudo pacman -S --needed --noconfirm git base-devel
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

PACMAN_PKGS=(
    # Wayland / Hyprland core
    hyprland uwsm hypridle hyprlock hyprsunset hyprpicker
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    xdg-utils xdg-user-dirs

    # Session / display manager
    sddm

    # Status bar
    waybar

    # Notifications
    mako

    # Wallpaper
    swaybg

    # OSD
    swayosd

    # Audio
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
    pamixer playerctl pavucontrol

    # Bluetooth
    bluez bluez-utils

    # Brightness / power
    brightnessctl power-profiles-daemon

    # Screenshot / screen capture
    grim slurp wl-clipboard hyprland-guiutils
    tesseract tesseract-data-eng imagemagick

    # Network
    iwd

    # Polkit / keyring
    polkit-gnome gnome-keyring

    # Qt Wayland / theming
    qt5-wayland qt6-wayland kvantum-qt5

    # GTK / GNOME utilities
    nautilus gvfs gvfs-mtp gvfs-smb gnome-disk-utility
    gnome-calculator gnome-themes-extra

    # System monitor / TUI tools
    btop lazygit tmux fzf bat eza zoxide fastfetch starship
    fd ripgrep dust tldr

    # Fonts
    inter-font ttf-jetbrains-mono-nerd ttf-cascadia-mono-nerd
    ttf-firacode-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk

    # Clipboard history
    cliphist

    # Shell / utilities
    jq gum wget unzip less bash-completion rsync
    woff2-font-awesome git github-cli

    # Media
    mpv ffmpegthumbnailer

    # Input method
    fcitx5 fcitx5-gtk fcitx5-qt

    # Dev tools
    mise

    # System / misc
    flatpak ufw zram-generator
)

AUR_PKGS=(
    xdg-terminal-exec   # Not in core repos on plain Arch
    walker-bin           # App launcher
    ghostty              # Terminal emulator
    impala               # TUI wifi manager
    bluetui              # TUI bluetooth manager
    satty                # Screenshot annotator (AUR on some setups)
    wl-screenrec-git     # Screen recorder (GPU-accelerated)
    wiremix              # TUI audio mixer
    gpu-screen-recorder  # GPU-accelerated screen recorder
    yaru-icon-theme      # Icon theme (AUR on Arch)
)

# ── Optional package groups ───────────────────────────────────────────────────
ask_install() {
    local desc="$1"; shift
    local pkgs=("$@")
    read -r -p "$(echo -e "\n${YELLOW}Install ${desc}?${RESET} [y/N] ")" resp
    if [[ "${resp,,}" == "y" ]]; then
        info "Installing ${desc}…"
        yay -S --needed --noconfirm "${pkgs[@]}"
        success "${desc} installed."
    fi
}

install_optional_groups() {
    ask_install "NVIDIA drivers (nvidia-open-dkms)" \
        nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver

    ask_install "Docker & container tools" \
        docker docker-buildx docker-compose lazydocker

    ask_install "Virtualisation (KVM/QEMU/virt-manager)" \
        libvirt qemu-desktop qemu-full virt-manager virt-viewer \
        swtpm freerdp dnsmasq openbsd-netcat

    ask_install "Gaming (Steam/Heroic/Proton via Flatpak)" \
        flatpak heroic-games-launcher-bin umu

    ask_install "Creative apps (OBS, Blender, GIMP, Inkscape)" \
        obs-studio blender gimp inkscape

    ask_install "Office & productivity (LibreOffice, Thunderbird)" \
        libreoffice-fresh thunderbird

    ask_install "Dev editors (Cursor, VS Code)" \
        cursor-bin cursor-cli

    ask_install "Media & comms (Spotify, Obsidian, qBittorrent)" \
        spotify obsidian qbittorrent
}

# pipewire-jack conflicts with jack2. Remove jack2 first if present so the
# main pacman install doesn't abort on the conflict prompt.
if pacman -Q jack2 &>/dev/null; then
    info "Removing conflicting jack2 (replaced by pipewire-jack)…"
    sudo pacman -Rdd --noconfirm jack2
fi

info "Installing official packages…"
sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"

# Remove swayosd from AUR list if it was installed from pacman already
AUR_PKGS=("${AUR_PKGS[@]/swayosd/}")

info "Installing AUR packages…"
yay -S --needed --noconfirm "${AUR_PKGS[@]}"

success "Packages installed."

install_optional_groups

# ── 2. ENABLE SYSTEM SERVICES ────────────────────────────────────────────────
step "Enabling system services"

sudo systemctl enable sddm
sudo systemctl enable bluetooth
sudo systemctl enable iwd
sudo systemctl enable power-profiles-daemon
sudo systemctl enable ufw

# Enable docker if installed
if pacman -Q docker &>/dev/null; then
    sudo systemctl enable docker
    sudo usermod -aG docker "$USER"
    info "Added $USER to docker group (re-login needed)"
fi

# Enable libvirt if installed
if pacman -Q libvirt &>/dev/null; then
    sudo systemctl enable libvirtd
    sudo usermod -aG libvirt "$USER"
fi

success "Services enabled."

# ── 3. SDDM HYPRLAND SESSION ─────────────────────────────────────────────────
step "Setting up SDDM Hyprland session"

sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland-uwsm.desktop > /dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland (UWSM)
Comment=Hyprland via UWSM session manager
Exec=uwsm start -- Hyprland
DesktopNames=Hyprland
Type=Application
EOF

success "SDDM session file written."

# ── 4. DIRECTORY STRUCTURE ────────────────────────────────────────────────────
step "Creating config directories"

mkdir -p \
    "$CFG/hypr/scripts" \
    "$CFG/waybar/scripts" \
    "$CFG/walker/themes/custom" \
    "$CFG/mako" \
    "$CFG/ghostty" \
    "$CFG/swayosd" \
    "$CFG/btop" \
    "$HOME/.local/share/backgrounds" \
    "$HOME/Pictures/Screenshots" \
    "$HOME/Videos/Screencasts"

success "Directories created."

# ── 5. HELPER SCRIPTS (hl-* replacing omarchy-* binaries) ────────────────────
step "Writing helper scripts to $BIN_DIR"

# ── hl-system-lock ────────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-system-lock" <<'EOF'
#!/usr/bin/env bash
loginctl lock-session
EOF

# ── hl-system-wake ────────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-system-wake" <<'EOF'
#!/usr/bin/env bash
hyprctl dispatch dpms on
EOF

# ── hl-launch-walker ─────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-walker" <<'EOF'
#!/usr/bin/env bash
walker "$@"
EOF

# ── hl-launch-browser ────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-browser" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--private" ]]; then
    shift
    xdg-open "about:blank" &
    # Try common browsers in private mode
    for browser in firefox chromium google-chrome-stable; do
        if command -v "$browser" &>/dev/null; then
            "$browser" --incognito "$@" &
            exit 0
        fi
    done
else
    xdg-open "${1:-https://}" &
fi
EOF

# ── hl-launch-webapp ─────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-webapp" <<'EOF'
#!/usr/bin/env bash
URL="${1:-https://example.com}"
for browser in chromium google-chrome-stable firefox; do
    if command -v "$browser" &>/dev/null; then
        "$browser" "--app=$URL" &
        exit 0
    fi
done
xdg-open "$URL"
EOF

# ── hl-launch-or-focus ───────────────────────────────────────────────────────
# Usage: hl-launch-or-focus <class_regex> <launch_cmd>
cat > "$BIN_DIR/hl-launch-or-focus" <<'EOF'
#!/usr/bin/env bash
CLASS_REGEX="${1:?Usage: hl-launch-or-focus <class> <cmd>}"
LAUNCH_CMD="${2:?}"
shift 2

if hyprctl clients -j | jq -e --arg r "$CLASS_REGEX" \
    '[.[]] | map(select(.class | test($r;"i"))) | length > 0' &>/dev/null; then
    hyprctl dispatch focuswindow "class:${CLASS_REGEX}"
else
    eval "$LAUNCH_CMD" &
fi
EOF

# ── hl-launch-or-focus-tui ───────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-or-focus-tui" <<'EOF'
#!/usr/bin/env bash
APP="${1:?Usage: hl-launch-or-focus-tui <app>}"
if hyprctl clients -j | jq -e --arg a "$APP" \
    '[.[]] | map(select(.title | test($a;"i"))) | length > 0' &>/dev/null; then
    hyprctl dispatch focuswindow "title:${APP}"
else
    uwsm-app -- xdg-terminal-exec "$APP"
fi
EOF

# ── hl-launch-tui ────────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-tui" <<'EOF'
#!/usr/bin/env bash
uwsm-app -- xdg-terminal-exec "$@"
EOF

# ── hl-launch-editor ─────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-editor" <<'EOF'
#!/usr/bin/env bash
EDITOR="${VISUAL:-${EDITOR:-nvim}}"
uwsm-app -- xdg-terminal-exec "$EDITOR"
EOF

# ── hl-launch-audio ──────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-audio" <<'EOF'
#!/usr/bin/env bash
if command -v pavucontrol &>/dev/null; then
    uwsm-app -- pavucontrol &
elif command -v wiremix &>/dev/null; then
    uwsm-app -- xdg-terminal-exec wiremix
fi
EOF

# ── hl-launch-wifi ───────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-wifi" <<'EOF'
#!/usr/bin/env bash
if command -v impala &>/dev/null; then
    uwsm-app -- xdg-terminal-exec impala
elif command -v nmtui &>/dev/null; then
    uwsm-app -- xdg-terminal-exec nmtui
fi
EOF

# ── hl-launch-bluetooth ──────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-bluetooth" <<'EOF'
#!/usr/bin/env bash
if command -v bluetui &>/dev/null; then
    uwsm-app -- xdg-terminal-exec bluetui
fi
EOF

# ── hl-launch-floating-terminal ──────────────────────────────────────────────
cat > "$BIN_DIR/hl-launch-floating-terminal" <<'EOF'
#!/usr/bin/env bash
uwsm-app -- xdg-terminal-exec "$@"
EOF

# ── hl-swayosd-client ────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-swayosd-client" <<'EOF'
#!/usr/bin/env bash
exec swayosd-client "$@"
EOF

# ── hl-audio-input-mute ──────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-audio-input-mute" <<'EOF'
#!/usr/bin/env bash
pamixer --default-source -t
swayosd-client --input-volume mute-toggle 2>/dev/null || true
EOF

# ── hl-audio-output-switch ───────────────────────────────────────────────────
cat > "$BIN_DIR/hl-audio-output-switch" <<'EOF'
#!/usr/bin/env bash
# Cycle through available PulseAudio sinks
sinks=$(pactl list short sinks | awk '{print $1}')
active=$(pactl get-default-sink)
active_id=$(pactl list short sinks | awk -v s="$active" '$2==s {print $1}')
next=$(echo "$sinks" | awk -v cur="$active_id" 'found{print;exit} $0==cur{found=1} END{if(!found)print NR}')
[[ -z "$next" ]] && next=$(echo "$sinks" | head -1)
sink_name=$(pactl list short sinks | awk -v id="$next" '$1==id {print $2}')
pactl set-default-sink "$sink_name"
notify-send -u low "Audio output" "Switched to $sink_name"
EOF

# ── hl-brightness-display ────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-brightness-display" <<'EOF'
#!/usr/bin/env bash
brightnessctl s "$1"
swayosd-client --brightness "$1" 2>/dev/null || true
EOF

# ── hl-brightness-keyboard ───────────────────────────────────────────────────
cat > "$BIN_DIR/hl-brightness-keyboard" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    up)   brightnessctl -d "*kbd_backlight*" s +10% 2>/dev/null ;;
    down) brightnessctl -d "*kbd_backlight*" s 10%- 2>/dev/null ;;
    cycle)
        curr=$(brightnessctl -d "*kbd_backlight*" g 2>/dev/null || echo 0)
        max=$(brightnessctl -d "*kbd_backlight*" m 2>/dev/null || echo 100)
        [[ "$curr" -eq 0 ]] && brightnessctl -d "*kbd_backlight*" s 50% \
            || brightnessctl -d "*kbd_backlight*" s 0%
        ;;
esac
EOF

# ── hl-toggle-touchpad ───────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-toggle-touchpad" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    on)  hyprctl keyword input:touchpad:enabled true ;;
    off) hyprctl keyword input:touchpad:enabled false ;;
    *)
        state=$(hyprctl getoption input:touchpad:enabled | grep -o 'int: [01]' | awk '{print $2}')
        if [[ "$state" == "1" ]]; then
            hyprctl keyword input:touchpad:enabled false
            notify-send -u low "Touchpad" "Disabled"
        else
            hyprctl keyword input:touchpad:enabled true
            notify-send -u low "Touchpad" "Enabled"
        fi
        ;;
esac
EOF

# ── hl-toggle-idle ───────────────────────────────────────────────────────────
IDLE_STATE_FILE="$HOME/.local/state/hl/idle-inhibit"
mkdir -p "$HOME/.local/state/hl"
cat > "$BIN_DIR/hl-toggle-idle" <<EOF
#!/usr/bin/env bash
STATE_FILE="$IDLE_STATE_FILE"
if [[ -f "\$STATE_FILE" ]]; then
    rm -f "\$STATE_FILE"
    pkill -f "systemd-inhibit.*sleep" 2>/dev/null || true
    notify-send -u low "Idle" "Auto-sleep enabled"
    echo '{"text":"","class":"","tooltip":"Idle lock enabled"}'
else
    touch "\$STATE_FILE"
    systemd-inhibit --what=sleep:idle --who=hl-toggle-idle --why="User inhibited" sleep infinity &
    notify-send -u low "Idle" "Auto-sleep disabled"
    echo '{"text":"󰤄","class":"active","tooltip":"Idle lock disabled"}'
fi
EOF

# ── hl-idle-status (for waybar) ──────────────────────────────────────────────
cat > "$BIN_DIR/hl-idle-status" <<EOF
#!/usr/bin/env bash
if [[ -f "$IDLE_STATE_FILE" ]]; then
    echo '{"text":"󰤄","class":"active","tooltip":"Idle lock disabled"}'
else
    echo '{"text":"","class":"","tooltip":"Idle lock enabled"}'
fi
EOF

# ── hl-toggle-nightlight ─────────────────────────────────────────────────────
NIGHTLIGHT_STATE="$HOME/.local/state/hl/nightlight"
cat > "$BIN_DIR/hl-toggle-nightlight" <<EOF
#!/usr/bin/env bash
STATE="$NIGHTLIGHT_STATE"
if pgrep -x hyprsunset &>/dev/null; then
    pkill -x hyprsunset
    rm -f "\$STATE"
    notify-send -u low "Night light" "Disabled"
else
    hyprsunset -t 4000 &
    touch "\$STATE"
    notify-send -u low "Night light" "Enabled (4000K)"
fi
EOF

# ── hl-toggle-waybar ─────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-toggle-waybar" <<'EOF'
#!/usr/bin/env bash
if pgrep -x waybar &>/dev/null; then
    pkill -x waybar
else
    uwsm-app -- waybar &
fi
EOF

# ── hl-toggle-notification-silencing ─────────────────────────────────────────
cat > "$BIN_DIR/hl-toggle-notification-silencing" <<'EOF'
#!/usr/bin/env bash
if makoctl mode | grep -q do-not-disturb; then
    makoctl mode -r do-not-disturb
    notify-send -u low "Notifications" "Enabled"
    echo '{"text":"","class":"","tooltip":"Notifications enabled"}'
else
    makoctl mode -a do-not-disturb
    echo '{"text":"󰂛","class":"active","tooltip":"Do not disturb"}'
fi
EOF

# ── hl-notification-silencing-status (for waybar) ────────────────────────────
cat > "$BIN_DIR/hl-notification-silencing-status" <<'EOF'
#!/usr/bin/env bash
if makoctl mode 2>/dev/null | grep -q do-not-disturb; then
    echo '{"text":"󰂛","class":"active","tooltip":"Do not disturb"}'
else
    echo '{"text":"","class":"","tooltip":"Notifications enabled"}'
fi
EOF

# ── hl-capture-screenshot ────────────────────────────────────────────────────
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
cat > "$BIN_DIR/hl-capture-screenshot" <<EOF
#!/usr/bin/env bash
OUTDIR="$SCREENSHOT_DIR"
OUTFILE="\$OUTDIR/\$(date +%Y%m%d-%H%M%S).png"
mkdir -p "\$OUTDIR"
if command -v satty &>/dev/null; then
    grim -g "\$(slurp)" - | satty -f - --output-filename "\$OUTFILE" --copy-command wl-copy
else
    grim -g "\$(slurp)" "\$OUTFILE" && wl-copy < "\$OUTFILE"
fi
notify-send -u low "Screenshot" "Saved to \$OUTFILE"
EOF

# ── hl-capture-text-extraction ───────────────────────────────────────────────
cat > "$BIN_DIR/hl-capture-text-extraction" <<'EOF'
#!/usr/bin/env bash
TMP=$(mktemp /tmp/ocr-XXXXXX.png)
grim -g "$(slurp)" "$TMP"
text=$(tesseract "$TMP" stdout 2>/dev/null)
rm -f "$TMP"
echo "$text" | wl-copy
notify-send -u low "OCR" "Text copied to clipboard"
EOF

# ── hl-capture-screenrecording ───────────────────────────────────────────────
SCREENRECORD_DIR="$HOME/Videos/Screencasts"
cat > "$BIN_DIR/hl-capture-screenrecording" <<EOF
#!/usr/bin/env bash
OUTDIR="$SCREENRECORD_DIR"
mkdir -p "\$OUTDIR"
if pgrep -x wl-screenrec &>/dev/null; then
    pkill -INT -x wl-screenrec
    notify-send -u low "Recording" "Saved to \$OUTDIR"
else
    OUTFILE="\$OUTDIR/\$(date +%Y%m%d-%H%M%S).mp4"
    wl-screenrec -f "\$OUTFILE" &
    notify-send -u low "Recording" "Started"
fi
EOF

# ── hl-screenrecording-status (for waybar) ───────────────────────────────────
cat > "$BIN_DIR/hl-screenrecording-status" <<'EOF'
#!/usr/bin/env bash
if pgrep -x wl-screenrec &>/dev/null; then
    echo '{"text":"⏺","class":"active","tooltip":"Recording in progress"}'
else
    echo '{"text":"","class":"","tooltip":"Screen recording"}'
fi
EOF

# ── hl-window-pop ────────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-window-pop" <<'EOF'
#!/usr/bin/env bash
hyprctl dispatch togglefloating
hyprctl dispatch pin
EOF

# ── hl-window-close-all ──────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-window-close-all" <<'EOF'
#!/usr/bin/env bash
hyprctl clients -j | jq -r '.[].address' | while read -r addr; do
    hyprctl dispatch closewindow "address:$addr"
done
EOF

# ── hl-window-transparency-toggle ────────────────────────────────────────────
cat > "$BIN_DIR/hl-window-transparency-toggle" <<'EOF'
#!/usr/bin/env bash
curr=$(hyprctl getoption decoration:active_opacity | grep 'float:' | awk '{print $2}')
if (( $(echo "$curr > 0.95" | bc -l) )); then
    hyprctl keyword decoration:active_opacity 0.85
    hyprctl keyword decoration:inactive_opacity 0.80
else
    hyprctl keyword decoration:active_opacity 0.95
    hyprctl keyword decoration:inactive_opacity 0.90
fi
EOF

# ── hl-window-gaps-toggle ────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-window-gaps-toggle" <<'EOF'
#!/usr/bin/env bash
curr=$(hyprctl getoption general:gaps_out | grep 'int:' | awk '{print $2}')
if [[ "$curr" == "0" ]]; then
    hyprctl keyword general:gaps_in 2
    hyprctl keyword general:gaps_out 4
else
    hyprctl keyword general:gaps_in 0
    hyprctl keyword general:gaps_out 0
fi
EOF

# ── hl-monitor-scaling-cycle ─────────────────────────────────────────────────
cat > "$BIN_DIR/hl-monitor-scaling-cycle" <<'EOF'
#!/usr/bin/env bash
SCALES=(1.0 1.25 1.5 2.0)
MON=$(hyprctl monitors -j | jq -r '.[0].name')
CURR=$(hyprctl monitors -j | jq -r '.[0].scale')
idx=0
for i in "${!SCALES[@]}"; do
    [[ "${SCALES[$i]}" == "$CURR" ]] && idx=$i
done
if [[ "$1" == "--reverse" ]]; then
    next=$(( (idx - 1 + ${#SCALES[@]}) % ${#SCALES[@]} ))
else
    next=$(( (idx + 1) % ${#SCALES[@]} ))
fi
hyprctl keyword monitor "$MON,preferred,auto,${SCALES[$next]}"
notify-send -u low "Monitor scale" "${SCALES[$next]}x"
EOF

# ── hl-cmd-terminal-cwd ──────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-cmd-terminal-cwd" <<'EOF'
#!/usr/bin/env bash
# Returns the working directory of the active terminal window's process.
addr=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
[[ -z "$addr" ]] && echo "$HOME" && exit 0

pid=$(hyprctl activewindow -j | jq -r '.pid // empty')
[[ -z "$pid" ]] && echo "$HOME" && exit 0

# Walk up process tree to find a shell with a useful cwd
cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || echo "$HOME")

# If cwd is root, home, or the terminal's own path, try children
if [[ "$cwd" == "/" || "$cwd" == "$HOME" ]]; then
    child=$(ls /proc/$pid/task/ 2>/dev/null | head -1)
    child_cwd=$(readlink -f "/proc/$child/cwd" 2>/dev/null || echo "$HOME")
    [[ -n "$child_cwd" && "$child_cwd" != "/" ]] && cwd="$child_cwd"
fi

echo "$cwd"
EOF

# ── hl-battery-status ────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-battery-status" <<'EOF'
#!/usr/bin/env bash
upower -i "$(upower -e | grep battery | head -1)" 2>/dev/null \
    | awk '/state|percentage|time to/{printf "%s\n",$0}' \
    | sed 's/^[[:space:]]*//'
EOF

# ── hl-update-available (for waybar) ─────────────────────────────────────────
cat > "$BIN_DIR/hl-update-available" <<'EOF'
#!/usr/bin/env bash
# Returns empty string when no updates, or shows update icon.
count=$(checkupdates 2>/dev/null | wc -l)
aur_count=$(yay -Qua 2>/dev/null | wc -l)
total=$(( count + aur_count ))
if [[ $total -gt 0 ]]; then
    echo "󰚰 $total"
fi
EOF

# ── hl-menu-system ───────────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-menu-system" <<'EOF'
#!/usr/bin/env bash
CHOICE=$(printf "  Lock\n  Logout\n  Reboot\n  Shutdown\n  Suspend" \
    | walker --dmenu --placeholder "System..." 2>/dev/null \
    | sed 's/^[[:space:]]*//')
case "$CHOICE" in
    *Lock)     hl-system-lock ;;
    *Logout)   uwsm stop ;;
    *Reboot)   systemctl reboot ;;
    *Shutdown) systemctl poweroff ;;
    *Suspend)  systemctl suspend ;;
esac
EOF

# ── hl-menu-keybindings ──────────────────────────────────────────────────────
cat > "$BIN_DIR/hl-menu-keybindings" <<'EOF'
#!/usr/bin/env bash
hyprctl binds -j 2>/dev/null \
    | jq -r '.[] | "\(.modmask) \(.key) → \(.description // .dispatcher + " " + .arg)"' \
    | sort \
    | walker --dmenu --placeholder "Keybindings…" 2>/dev/null || true
EOF

# ── hl-reminder ──────────────────────────────────────────────────────────────
REMINDER_DIR="$HOME/.local/state/hl/reminders"
mkdir -p "$REMINDER_DIR"
cat > "$BIN_DIR/hl-reminder" <<EOF
#!/usr/bin/env bash
RDIR="$REMINDER_DIR"
mkdir -p "\$RDIR"

case "\${1:-}" in
    show)
        ls "\$RDIR" 2>/dev/null | while read -r f; do
            source "\$RDIR/\$f"
            echo "\$LABEL (in \$(( (TRIGGER - \$(date +%s)) / 60 )) min)"
        done
        ;;
    clear)
        for f in "\$RDIR/"*; do
            [[ -f "\$f" ]] && { source "\$f"; pkill -P "\$PID" 2>/dev/null; kill "\$PID" 2>/dev/null; rm -f "\$f"; }
        done
        notify-send -u low "Reminders" "All cleared"
        ;;
    *)
        MINS="\${1:?Usage: hl-reminder <minutes> [message]}"
        MSG="\${2:-Reminder}"
        TRIGGER=\$(( \$(date +%s) + MINS * 60 ))
        (
            sleep \$(( MINS * 60 ))
            notify-send -u critical "⏰ \$MSG" "Your reminder"
        ) &
        PID=\$!
        LABEL="\$MSG"
        echo "PID=\$PID; TRIGGER=\$TRIGGER; LABEL=\"\$MSG\"" > "\$RDIR/\${PID}.env"
        notify-send -u low "Reminder set" "\$MSG in \$MINS minutes"
        ;;
esac
EOF

chmod +x "$BIN_DIR"/hl-*
success "Helper scripts written."

# ── 6. SYS-* COMPATIBILITY STUBS ─────────────────────────────────────────────
# The dotfiles' hypr/defaults/ reference sys-* commands from the old system
# scripts dir (~/.local/share/system/bin/). These stubs provide minimal
# compatible behaviour on a fresh install until the full system dir is set up.
step "Writing sys-* compatibility stubs"

# sys-toggle-enabled: returns 1 (not enabled) — defaults fire their commands
cat > "$BIN_DIR/sys-toggle-enabled" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

# sys-cmd-present: checks if a command exists
cat > "$BIN_DIR/sys-cmd-present" <<'EOF'
#!/usr/bin/env bash
command -v "$1" &>/dev/null
EOF

# sys-first-run: no-op on fresh install
cat > "$BIN_DIR/sys-first-run" <<'EOF'
#!/usr/bin/env bash
true
EOF

# sys-powerprofiles-init: set balanced profile if power-profiles-daemon is running
cat > "$BIN_DIR/sys-powerprofiles-init" <<'EOF'
#!/usr/bin/env bash
powerprofilesctl set balanced 2>/dev/null || true
EOF

# sys-hyprland-monitor-watch: long-running watcher stub (sleeps until killed)
cat > "$BIN_DIR/sys-hyprland-monitor-watch" <<'EOF'
#!/usr/bin/env bash
sleep infinity
EOF

# sys-hook: no-op hook runner
cat > "$BIN_DIR/sys-hook" <<'EOF'
#!/usr/bin/env bash
true
EOF

# system-update: personal update script (mirrors omarchy update pipeline)
cat > "$BIN_DIR/system-update" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" != "-y" ]] && read -r -p "Run full system update? [y/N] " r && [[ "${r,,}" != "y" ]] && exit 0

echo "→ Refreshing keyring…"
sudo pacman -S --noconfirm archlinux-keyring

echo "→ Upgrading system packages…"
sudo pacman -Syyu --noconfirm

if command -v yay &>/dev/null && curl -s --head https://aur.archlinux.org >/dev/null 2>&1; then
    echo "→ Upgrading AUR packages…"
    yay -Sua --noconfirm --cleanafter
fi

orphans=$(pacman -Qtdq 2>/dev/null) || true
if [[ -n "$orphans" ]]; then
    echo "→ Removing orphans: $orphans"
    sudo pacman -Rns --noconfirm $orphans
fi

echo "Update complete."
if pacman -Q linux &>/dev/null && [[ "$(uname -r)" != "$(pacman -Q linux | awk '{print $2}')-$(uname -m)" ]]; then
    read -r -p "Kernel updated — reboot now? [y/N] " r
    [[ "${r,,}" == "y" ]] && systemctl reboot --no-wall
fi
EOF

chmod +x "$BIN_DIR"/sys-* "$BIN_DIR/system-update"
success "Sys-* stubs written."

# ── 7. DEPLOY DOTFILES ────────────────────────────────────────────────────────
step "Deploying dotfiles"

if [[ -f "$SCRIPT_DIR/install" ]]; then
    info "Running dotfiles install from $SCRIPT_DIR…"
    bash "$SCRIPT_DIR/install"
    success "Dotfiles deployed."
else
    warn "Dotfiles install script not found at $SCRIPT_DIR/install"
    warn "Writing minimal fallback configs…"
    _write_fallback_configs
fi

# ── FALLBACK CONFIG FUNCTION ──────────────────────────────────────────────────
# Called only when dotfiles/install is not available. Writes self-contained
# configs that do not depend on desktop theme infrastructure or sys-* scripts.
_write_fallback_configs() {

# ── hyprland.conf ─────────────────────────────────────────────────────────────
cat > "$CFG/hypr/hyprland.conf" <<'EOF'
# Main Hyprland config — sources modular files

source = ~/.config/hypr/envs.conf
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/looknfeel.conf
source = ~/.config/hypr/windows.conf
source = ~/.config/hypr/autostart.conf
source = ~/.config/hypr/bindings/tiling.conf
source = ~/.config/hypr/bindings/media.conf
source = ~/.config/hypr/bindings/utilities.conf
source = ~/.config/hypr/bindings/apps.conf

# Blur on layer surfaces
layerrule = blur on, ignore_alpha 0.1, match:namespace waybar
layerrule = blur on, ignore_alpha 0,   match:namespace walker
layerrule = blur on, ignore_alpha 0.1, match:namespace notifications
layerrule = blur on, ignore_alpha 0.1, match:namespace swayosd
EOF

# ── envs.conf ────────────────────────────────────────────────────────────────
cat > "$CFG/hypr/envs.conf" <<'EOF'
# Cursor size
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24

# Force all apps to use Wayland
env = GDK_BACKEND,wayland,x11,*
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_STYLE_OVERRIDE,kvantum
env = MOZ_ENABLE_WAYLAND,1
env = ELECTRON_OZONE_PLATFORM_HINT,wayland
env = OZONE_PLATFORM,wayland
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_DESKTOP,Hyprland

# Screenshot / screencast output directories
env = HL_SCREENSHOT_DIR,$HOME/Pictures/Screenshots
env = HL_SCREENRECORD_DIR,$HOME/Videos/Screencasts

xwayland {
  force_zero_scaling = true
}

ecosystem {
  no_update_news = true
}
EOF

# ── monitors.conf ─────────────────────────────────────────────────────────────
cat > "$CFG/hypr/monitors.conf" <<'EOF'
# Hyprland monitor config — adjust to your hardware.
# Run: hyprctl monitors   to list available outputs.

# Default: auto-detect everything at preferred resolution and scale
monitor = , preferred, auto, 1

# Example for a 1080p laptop display:
# monitor = eDP-1, 1920x1080@144, 0x0, 1.0

# Example for external 1440p monitor to the right:
# monitor = DP-1, 2560x1440@60, 1920x0, 1.0
EOF

# ── input.conf ────────────────────────────────────────────────────────────────
cat > "$CFG/hypr/input.conf" <<'EOF'
input {
    kb_layout = us
    kb_options =

    repeat_rate = 40
    repeat_delay = 250

    numlock_by_default = true
    sensitivity = 0.25
    follow_mouse = 2
    float_switch_override_focus = 0

    touchpad {
        clickfinger_behavior = true
        scroll_factor = 0.4
    }
}

misc {
    key_press_enables_dpms  = true
    mouse_move_enables_dpms = true
}

windowrule = match:class com.mitchellh.ghostty, scroll_touchpad 0.2
EOF

# ── looknfeel.conf ────────────────────────────────────────────────────────────
cat > "$CFG/hypr/looknfeel.conf" <<'EOF'
# Colour variables — Nord-inspired dark palette
$activeBorderColor   = rgb(3b4252)
$inactiveBorderColor = rgba(59595980)

general {
    gaps_in    = 2
    gaps_out   = 4
    border_size = 2

    col.active_border   = $activeBorderColor
    col.inactive_border = $inactiveBorderColor

    layout = dwindle
}

decoration {
    rounding        = 12
    active_opacity  = 0.95
    inactive_opacity = 0.90

    blur {
        enabled          = true
        size             = 8
        passes           = 5
        noise            = 0.0117
        brightness       = 0.8
        vibrancy         = 0.16
        vibrancy_darkness = 0.0
        new_optimizations = true
    }

    shadow {
        enabled      = true
        range        = 20
        render_power = 3
        color        = rgba(00000066)
    }

    dim_inactive = true
    dim_strength = 0.05
}

animations {
    enabled = yes

    bezier = easeOutQuint,0.23,1,0.32,1
    bezier = easeInOutCubic,0.65,0.05,0.36,1
    bezier = almostLinear,0.5,0.5,0.75,1.0
    bezier = quick,0.15,0,0.1,1

    animation = windows,    1, 3.79, easeOutQuint
    animation = windowsIn,  1, 4.1,  easeOutQuint, popin 87%
    animation = windowsOut, 1, 1.49, quick,        popin 87%
    animation = fade,       1, 3.03, quick
    animation = layers,     1, 3.81, easeOutQuint
    animation = layersIn,   1, 4,    easeOutQuint, fade
    animation = layersOut,  1, 1.5,  quick,        fade
    animation = workspaces, 0, 0,    quick
    animation = specialWorkspace, 1, 3, easeOutQuint, slidevert
}

dwindle {
    preserve_split = true
    force_split    = 2
}

scrolling {
    column_width           = 0.49
    fullscreen_on_one_column = true
}

group {
    col.border_active          = $activeBorderColor
    col.border_inactive        = $inactiveBorderColor
    col.border_locked_active   = $activeBorderColor
    col.border_locked_inactive = $inactiveBorderColor

    groupbar {
        font_size   = 12
        font_family = monospace
        height      = 22
        gaps_in     = 5

        text_color          = rgb(ffffff)
        text_color_inactive = rgba(ffffff90)
        col.active          = rgba(00000040)
        col.inactive        = rgba(00000020)
        gradients           = true
        indicator_height    = 0
    }
}

misc {
    disable_hyprland_logo      = true
    disable_splash_rendering   = true
    disable_scale_notification = true
    focus_on_activate          = true
    anr_missed_pings           = 3
    on_focus_under_fullscreen  = 1
}

cursor {
    hide_on_key_press       = true
    warp_on_change_workspace = 1
}

binds {
    hide_special_on_workspace_change = true
}
EOF

# ── windows.conf ──────────────────────────────────────────────────────────────
cat > "$CFG/hypr/windows.conf" <<'EOF'
# Window rules (Hyprland 0.53+ syntax)
windowrule = suppress_event maximize, match:class .*
windowrule = tag +default-opacity, match:class .*

# XWayland drag fix
windowrule = no_focus on, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0

# Default opacity after apps opt in/out
windowrule = opacity 0.97 0.9, match:tag default-opacity

# Floating tool windows
windowrule = float on,  match:class (org.gnome.Calculator|pavucontrol|blueman-manager)
windowrule = center on, match:class (org.gnome.Calculator|pavucontrol|blueman-manager)
EOF

# ── autostart.conf ────────────────────────────────────────────────────────────
cat > "$CFG/hypr/autostart.conf" <<'EOF'
exec-once = uwsm-app -- hypridle
exec-once = uwsm-app -- mako
exec-once = uwsm-app -- waybar
exec-once = uwsm-app -- swaybg -i ~/.local/share/backgrounds/wallpaper -m fill
exec-once = uwsm-app -- swayosd-server
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = uwsm-app -- wl-paste --type text  --watch cliphist store
exec-once = uwsm-app -- wl-paste --type image --watch cliphist store

# Systemd environment
exec-once = systemctl --user import-environment $(env | cut -d'=' -f1)
exec-once = dbus-update-activation-environment --systemd --all

# XDG user dirs
exec-once = xdg-user-dirs-update
EOF

# ── bindings/tiling.conf ──────────────────────────────────────────────────────
mkdir -p "$CFG/hypr/bindings"
cat > "$CFG/hypr/bindings/tiling.conf" <<'EOF'
# Window management
bindd = SUPER, W,       Close window,          killactive,
bindd = SUPER, J,       Toggle split,          layoutmsg, togglesplit
bindd = SUPER, T,       Toggle floating,       togglefloating,
bindd = SUPER, F,       Full screen,           fullscreen, 0
bindd = SUPER CTRL, F,  Tiled full screen,     fullscreenstate, 0 2
bindd = SUPER, P,       Pseudo window,         pseudo,
bindd = SUPER, O,       Pop window,            exec, hl-window-pop
bindd = SUPER, L,       Toggle layout,         exec, ~/.config/hypr/scripts/toggle-layout.sh

# Focus
bindd = SUPER, LEFT,  Focus left,  movefocus, l
bindd = SUPER, RIGHT, Focus right, movefocus, r
bindd = SUPER, UP,    Focus up,    movefocus, u
bindd = SUPER, DOWN,  Focus down,  movefocus, d

# Workspaces 1-10
bindd = SUPER, code:10, Workspace 1,  workspace, 1
bindd = SUPER, code:11, Workspace 2,  workspace, 2
bindd = SUPER, code:12, Workspace 3,  workspace, 3
bindd = SUPER, code:13, Workspace 4,  workspace, 4
bindd = SUPER, code:14, Workspace 5,  workspace, 5
bindd = SUPER, code:15, Workspace 6,  workspace, 6
bindd = SUPER, code:16, Workspace 7,  workspace, 7
bindd = SUPER, code:17, Workspace 8,  workspace, 8
bindd = SUPER, code:18, Workspace 9,  workspace, 9
bindd = SUPER, code:19, Workspace 10, workspace, 10

# Move to workspace
bindd = SUPER SHIFT, code:10, Move to workspace 1,  movetoworkspace, 1
bindd = SUPER SHIFT, code:11, Move to workspace 2,  movetoworkspace, 2
bindd = SUPER SHIFT, code:12, Move to workspace 3,  movetoworkspace, 3
bindd = SUPER SHIFT, code:13, Move to workspace 4,  movetoworkspace, 4
bindd = SUPER SHIFT, code:14, Move to workspace 5,  movetoworkspace, 5
bindd = SUPER SHIFT, code:15, Move to workspace 6,  movetoworkspace, 6
bindd = SUPER SHIFT, code:16, Move to workspace 7,  movetoworkspace, 7
bindd = SUPER SHIFT, code:17, Move to workspace 8,  movetoworkspace, 8
bindd = SUPER SHIFT, code:18, Move to workspace 9,  movetoworkspace, 9
bindd = SUPER SHIFT, code:19, Move to workspace 10, movetoworkspace, 10

# Move silently
bindd = SUPER SHIFT ALT, code:10, Move silently to 1,  movetoworkspacesilent, 1
bindd = SUPER SHIFT ALT, code:11, Move silently to 2,  movetoworkspacesilent, 2
bindd = SUPER SHIFT ALT, code:12, Move silently to 3,  movetoworkspacesilent, 3
bindd = SUPER SHIFT ALT, code:13, Move silently to 4,  movetoworkspacesilent, 4
bindd = SUPER SHIFT ALT, code:14, Move silently to 5,  movetoworkspacesilent, 5
bindd = SUPER SHIFT ALT, code:15, Move silently to 6,  movetoworkspacesilent, 6
bindd = SUPER SHIFT ALT, code:16, Move silently to 7,  movetoworkspacesilent, 7
bindd = SUPER SHIFT ALT, code:17, Move silently to 8,  movetoworkspacesilent, 8
bindd = SUPER SHIFT ALT, code:18, Move silently to 9,  movetoworkspacesilent, 9
bindd = SUPER SHIFT ALT, code:19, Move silently to 10, movetoworkspacesilent, 10

# Scratchpad
bindd = SUPER, S,     Toggle scratchpad, togglespecialworkspace, scratchpad
bindd = SUPER ALT, S, Move to scratchpad, movetoworkspacesilent, special:scratchpad

# Navigate workspaces
bindd = SUPER, TAB,       Next workspace,    workspace, e+1
bindd = SUPER SHIFT, TAB, Previous workspace, workspace, e-1
bindd = SUPER CTRL, TAB,  Former workspace,  workspace, previous
bind  = CTRL SUPER, right, workspace, e+1
bind  = CTRL SUPER, left,  workspace, e-1

# Swap windows
bindd = SUPER SHIFT, LEFT,  Swap left,  swapwindow, l
bindd = SUPER SHIFT, RIGHT, Swap right, swapwindow, r
bindd = SUPER SHIFT, UP,    Swap up,    swapwindow, u
bindd = SUPER SHIFT, DOWN,  Swap down,  swapwindow, d

# Cycle windows
bindd = ALT, TAB,       Next window,     cyclenext
bindd = ALT SHIFT, TAB, Previous window, cyclenext, prev
bindd = ALT, TAB,       Raise active,    bringactivetotop
bindd = ALT SHIFT, TAB, Raise active,    bringactivetotop

# Monitor focus cycle
bindd = CTRL ALT, TAB,       Next monitor,     focusmonitor, +1
bindd = CTRL ALT SHIFT, TAB, Previous monitor, focusmonitor, -1

# Resize
bindd = SUPER, code:20, Shrink window, resizeactive, -100 0
bindd = SUPER, code:21, Expand window,  resizeactive,  100 0
bindd = SUPER SHIFT, code:20, Shrink height, resizeactive, 0 -100
bindd = SUPER SHIFT, code:21, Expand height, resizeactive, 0  100

# Mouse
bindd = SUPER, mouse_down, Scroll workspace forward,  workspace, e+1
bindd = SUPER, mouse_up,   Scroll workspace backward, workspace, e-1
bindmd = SUPER, mouse:272, Move window,   movewindow
bindmd = SUPER, mouse:273, Resize window, resizewindow

# Groups
bindd = SUPER, G,           Toggle group,     togglegroup
bindd = SUPER ALT, G,       Leave group,      moveoutofgroup
bindd = SUPER ALT, LEFT,    Join group left,  moveintogroup, l
bindd = SUPER ALT, RIGHT,   Join group right, moveintogroup, r
bindd = SUPER ALT, UP,      Join group up,    moveintogroup, u
bindd = SUPER ALT, DOWN,    Join group down,  moveintogroup, d
bindd = SUPER ALT, TAB,     Next in group,    changegroupactive, f
bindd = SUPER ALT SHIFT, TAB, Prev in group,  changegroupactive, b
bindd = SUPER CTRL, LEFT,   Group focus back,    changegroupactive, b
bindd = SUPER CTRL, RIGHT,  Group focus forward, changegroupactive, f

# Move workspace to monitor
bindd = SUPER SHIFT ALT, LEFT,  Move workspace left,  movecurrentworkspacetomonitor, l
bindd = SUPER SHIFT ALT, RIGHT, Move workspace right, movecurrentworkspacetomonitor, r
bindd = SUPER SHIFT ALT, UP,    Move workspace up,    movecurrentworkspacetomonitor, u
bindd = SUPER SHIFT ALT, DOWN,  Move workspace down,  movecurrentworkspacetomonitor, d

# Monitor scaling
bindd = SUPER, code:61,     Scale up,   exec, hl-monitor-scaling-cycle
bindd = SUPER ALT, code:61, Scale down, exec, hl-monitor-scaling-cycle --reverse
EOF

# ── bindings/media.conf ───────────────────────────────────────────────────────
cat > "$CFG/hypr/bindings/media.conf" <<'EOF'
# Volume
bindeld = , XF86AudioRaiseVolume, Volume up,   exec, swayosd-client --output-volume raise
bindeld = , XF86AudioLowerVolume, Volume down, exec, swayosd-client --output-volume lower
bindeld = , XF86AudioMute,        Mute,        exec, swayosd-client --output-volume mute-toggle
bindeld = , XF86AudioMicMute,     Mic mute,    exec, hl-audio-input-mute

bindeld = ALT, XF86AudioRaiseVolume, Volume +1, exec, swayosd-client --output-volume +1
bindeld = ALT, XF86AudioLowerVolume, Volume -1, exec, swayosd-client --output-volume -1

# Brightness
bindeld = , XF86MonBrightnessUp,    Brightness up,   exec, hl-brightness-display +5%
bindeld = , XF86MonBrightnessDown,  Brightness down, exec, hl-brightness-display 5%-
bindeld = SHIFT, XF86MonBrightnessUp,   Max brightness, exec, hl-brightness-display 100%
bindeld = SHIFT, XF86MonBrightnessDown, Min brightness, exec, hl-brightness-display 1%

bindeld = ALT, XF86MonBrightnessUp,   Brightness +1%, exec, hl-brightness-display +1%
bindeld = ALT, XF86MonBrightnessDown, Brightness -1%, exec, hl-brightness-display 1%-

# Keyboard backlight
bindeld = , XF86KbdBrightnessUp,   KB backlight up,    exec, hl-brightness-keyboard up
bindeld = , XF86KbdBrightnessDown, KB backlight down,  exec, hl-brightness-keyboard down
bindld  = , XF86KbdLightOnOff,     KB backlight cycle, exec, hl-brightness-keyboard cycle

# Media
bindld = , XF86AudioNext,  Next track,  exec, swayosd-client --playerctl next
bindld = , XF86AudioPrev,  Prev track,  exec, swayosd-client --playerctl previous
bindld = , XF86AudioPlay,  Play/pause,  exec, swayosd-client --playerctl play-pause
bindld = , XF86AudioPause, Pause,       exec, swayosd-client --playerctl play-pause

# Touchpad
bindld = , XF86TouchpadToggle, Toggle touchpad, exec, hl-toggle-touchpad
bindld = , XF86TouchpadOn,     Enable touchpad, exec, hl-toggle-touchpad on
bindld = , XF86TouchpadOff,    Disable touchpad, exec, hl-toggle-touchpad off

# Audio output switch
bindld = SUPER, XF86AudioMute, Switch audio output, exec, hl-audio-output-switch

# Power button
bindld = , XF86PowerOff, System menu, exec, hl-menu-system
EOF

# ── bindings/utilities.conf ───────────────────────────────────────────────────
cat > "$CFG/hypr/bindings/utilities.conf" <<'EOF'
# Launcher
bindd = SUPER, SPACE,       Launch apps,   exec, walker
bindd = SUPER CTRL, E,      Emoji picker,  exec, walker -m symbols
bindd = SUPER CTRL, V,      Clipboard,     exec, walker -m clipboard
bindd = SUPER, ESCAPE,      System menu,   exec, hl-menu-system
bindd = SUPER, K,           Keybindings,   exec, hl-menu-keybindings

# Notifications
bindd = SUPER, COMMA,           Dismiss notification,     exec, makoctl dismiss
bindd = SUPER SHIFT, COMMA,     Dismiss all,              exec, makoctl dismiss --all
bindd = SUPER CTRL, COMMA,      Toggle DND,               exec, hl-toggle-notification-silencing
bindd = SUPER ALT, COMMA,       Invoke notification,      exec, makoctl invoke
bindd = SUPER SHIFT ALT, COMMA, Restore notification,     exec, makoctl restore

# Toggles
bindd = SUPER CTRL, I, Toggle idle lock,    exec, hl-toggle-idle
bindd = SUPER CTRL, N, Toggle nightlight,   exec, hl-toggle-nightlight
bindd = SUPER SHIFT, SPACE, Toggle waybar,  exec, hl-toggle-waybar

# Aesthetics
bindd = SUPER, BACKSPACE,       Toggle transparency, exec, hl-window-transparency-toggle
bindd = SUPER SHIFT, BACKSPACE, Toggle gaps,         exec, hl-window-gaps-toggle

# Screenshots
bindd = , PRINT,         Screenshot,      exec, hl-capture-screenshot
bindd = ALT, PRINT,      Screen recording, exec, hl-capture-screenrecording
bindd = SUPER, PRINT,    Colour picker,   exec, pkill hyprpicker || hyprpicker -a
bindd = SUPER CTRL, PRINT, OCR text,      exec, hl-capture-text-extraction

# Lock
bindd = SUPER CTRL, L, Lock system, exec, hl-system-lock

# Copy / Paste (universal)
bindd = SUPER, C, Copy,  sendshortcut, CTRL,  Insert, activewindow
bindd = SUPER, V, Paste, sendshortcut, SHIFT, Insert, activewindow
bindd = SUPER, X, Cut,   sendshortcut, CTRL,  X,      activewindow

# Zoom
bindd = SUPER CTRL, Z, Zoom in, exec, hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float + 1')
bindd = SUPER CTRL ALT, Z, Reset zoom, exec, hyprctl keyword cursor:zoom_factor 1

# Controls
bindd = SUPER CTRL, A, Audio controls,   exec, hl-launch-audio
bindd = SUPER CTRL, B, Bluetooth,        exec, hl-launch-bluetooth
bindd = SUPER CTRL, W, Wi-Fi,            exec, hl-launch-wifi
bindd = SUPER CTRL, T, Activity monitor, exec, hl-launch-tui btop

# Reminders
bindd = SUPER CTRL, R,       Set reminder,   exec, walker --dmenu --placeholder "Reminder in X minutes message..."
bindd = SUPER CTRL ALT, R,   Show reminders, exec, hl-reminder show
bindd = SUPER SHIFT CTRL, R, Clear reminders, exec, hl-reminder clear

# Waybar-less info
bindd = SUPER CTRL ALT, T, Show time,    exec, notify-send -u low "   $(date +'%A %H:%M  ·  %d %B %Y  ·  Week %V')"
bindd = SUPER CTRL ALT, B, Battery info, exec, notify-send -u low "$(hl-battery-status)"

# Lid close / open
bindl = , switch:on:Lid Switch,  exec, hyprctl keyword monitor "eDP-1, disable"
bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "eDP-1, preferred, 0x0, 1"
EOF

# ── bindings/apps.conf ────────────────────────────────────────────────────────
cat > "$CFG/hypr/bindings/apps.conf" <<'EOF'
# Application launchers
bindd = SUPER, RETURN,             Terminal,         exec, uwsm-app -- xdg-terminal-exec --dir="$(hl-cmd-terminal-cwd)"
bindd = SUPER ALT, RETURN,         Tmux,             exec, uwsm-app -- xdg-terminal-exec bash -c "tmux attach || tmux new -s Work"
bindd = SUPER SHIFT, RETURN,       Browser,          exec, hl-launch-browser
bindd = SUPER SHIFT, F,            File manager,     exec, uwsm-app -- nautilus --new-window
bindd = SUPER SHIFT, B,            Browser,          exec, hl-launch-browser
bindd = SUPER SHIFT ALT, B,        Browser private,  exec, hl-launch-browser --private
bindd = SUPER SHIFT, N,            Editor,           exec, hl-launch-editor
bindd = SUPER SHIFT, D,            Docker TUI,       exec, hl-launch-tui lazydocker
bindd = SUPER SHIFT, G,            Signal,           exec, hl-launch-or-focus "^signal$" "uwsm-app -- signal-desktop"
bindd = SUPER SHIFT, O,            Obsidian,         exec, hl-launch-or-focus "^obsidian$" "uwsm-app -- obsidian"

# Layout toggle
bindd = SUPER ALT, L, Toggle layout (scrolling/dwindle), exec, ~/.config/hypr/scripts/toggle-layout.sh
EOF

# ── scripts/toggle-layout.sh ──────────────────────────────────────────────────
cat > "$CFG/hypr/scripts/toggle-layout.sh" <<'EOF'
#!/usr/bin/env bash
current=$(hyprctl getoption general:layout | awk '/^str:/ { print $2 }')
if [[ "$current" == "scrolling" ]]; then
    hyprctl keyword general:layout dwindle
else
    hyprctl keyword general:layout scrolling
fi
EOF
chmod +x "$CFG/hypr/scripts/toggle-layout.sh"

# ── hypridle.conf ─────────────────────────────────────────────────────────────
cat > "$CFG/hypr/hypridle.conf" <<'EOF'
general {
    lock_cmd        = loginctl lock-session
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd  = sleep 1 && hyprctl dispatch dpms on
    inhibit_sleep    = 3
}

listener {
    timeout    = 150
    on-timeout = pidof hyprlock || hyprlock --immediate &
}

listener {
    timeout    = 300
    on-timeout = loginctl lock-session
    on-resume  = hyprctl dispatch dpms on
}
EOF

# ── hyprlock.conf ─────────────────────────────────────────────────────────────
cat > "$CFG/hypr/hyprlock.conf" <<'EOF'
general {
    ignore_empty_input = true
}

background {
    monitor =
    color   = rgba(22, 22, 22, 1.0)
    path    = ~/.local/share/backgrounds/wallpaper
    blur_passes = 3
    blur_size   = 8
    noise       = 0.02
    contrast    = 0.9
    brightness  = 0.8
    vibrancy    = 0.15
}

animations {
    enabled = false
}

label {
    monitor     =
    text        = $TIME
    color       = rgba(216, 222, 233, 1.0)
    font_size   = 72
    font_family = JetBrainsMono Nerd Font Mono
    font_weight = 300
    position    = 0, 180
    halign      = center
    valign      = center
    shadow_passes = 0
}

label {
    monitor     =
    text        = cmd[update:60000] date '+%A, %B %-d'
    color       = rgba(216, 222, 233, 1.0)
    font_size   = 18
    font_family = JetBrainsMono Nerd Font Mono
    font_weight = 400
    position    = 0, 110
    halign      = center
    valign      = center
    shadow_passes = 0
}

input-field {
    monitor     =
    size        = 360, 52
    position    = 0, -40
    halign      = center
    valign      = center

    inner_color       = rgba(22, 22, 22, 0.8)
    outer_color       = rgba(216, 222, 233, 1.0)
    outline_thickness = 2

    font_family       = JetBrainsMono Nerd Font Mono
    font_color        = rgba(216, 222, 233, 1.0)
    placeholder_text  = Enter password
    check_color       = rgba(59, 66, 82, 1.0)
    fail_text         = <i>$FAIL ($ATTEMPTS)</i>

    rounding      = 12
    shadow_passes = 0
    fade_on_empty = false
}

auth {
    fingerprint:enabled = false
}
EOF

# ── hyprsunset.conf ───────────────────────────────────────────────────────────
cat > "$CFG/hypr/hyprsunset.conf" <<'EOF'
# hyprsunset — night light
# Run: uwsm-app -- hyprsunset   in autostart to enable

profile {
    time        = 07:00
    identity    = true
}

# Uncomment to auto-switch at 20:00:
# profile {
#     time        = 20:00
#     temperature = 4000
# }
EOF

success "Hyprland config written."

# ── 7. WAYBAR CONFIG ─────────────────────────────────────────────────────────
step "Writing Waybar config"

# ── tray-detect script ────────────────────────────────────────────────────────
mkdir -p "$CFG/waybar/scripts"
cat > "$CFG/waybar/scripts/tray-detect.sh" <<'EOF'
#!/usr/bin/env bash
ICON=$(printf '\xef\x81\x93')  # 
items=$(busctl --user get-property org.kde.StatusNotifierWatcher \
    /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher \
    RegisteredStatusNotifierItems 2>/dev/null)

if echo "$items" | grep -q "StatusNotifierItem"; then
    printf '{"text":"%s"}\n' "$ICON"
else
    printf '{"text":"%s","class":"hidden"}\n' "$ICON"
fi
EOF
chmod +x "$CFG/waybar/scripts/tray-detect.sh"

cat > "$CFG/waybar/config.jsonc" <<'EOF'
{
  "reload_style_on_change": true,
  "layer": "top",
  "position": "top",
  "spacing": 0,
  "height": 32,
  "margin-top": 6,
  "margin-left": 8,
  "margin-right": 8,

  "modules-left": [
    "custom/launcher",
    "hyprland/workspaces"
  ],
  "modules-center": [
    "mpris"
  ],
  "modules-right": [
    "group/tray-expander",
    "bluetooth",
    "network",
    "pulseaudio",
    "cpu",
    "battery",
    "clock",
    "custom/update",
    "custom/screenrecording",
    "custom/idle",
    "custom/dnd"
  ],

  // ── Left ──────────────────────────────────────────────────────────────────

  "custom/launcher": {
    "format": "",
    "on-click": "walker",
    "on-click-right": "xdg-terminal-exec",
    "tooltip": false
  },

  "hyprland/workspaces": {
    "on-click": "activate",
    "format": "{icon}",
    "format-icons": {
      "default": "",
      "active":  "󱓻",
      "1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
      "6": "6", "7": "7", "8": "8", "9": "9", "10": "0"
    },
    "persistent-workspaces": {
      "1": [], "2": [], "3": [], "4": [], "5": []
    }
  },

  // ── Center ────────────────────────────────────────────────────────────────

  "mpris": {
    "format": "{player_icon}  {dynamic}",
    "format-paused": "{status_icon}  {dynamic}",
    "dynamic-order": ["title", "artist"],
    "player-icons": { "default": "", "mpv": "🎵" },
    "status-icons": { "paused": "" }
  },

  // ── Right ─────────────────────────────────────────────────────────────────

  "custom/update": {
    "format": "{}",
    "exec": "hl-update-available",
    "on-click": "xdg-terminal-exec sudo pacman -Syu",
    "tooltip-format": "System update available",
    "interval": 21600
  },

  "custom/screenrecording": {
    "exec": "hl-screenrecording-status",
    "on-click": "hl-capture-screenrecording",
    "return-type": "json",
    "interval": 3
  },

  "custom/idle": {
    "exec": "hl-idle-status",
    "on-click": "hl-toggle-idle",
    "return-type": "json",
    "interval": 5
  },

  "custom/dnd": {
    "exec": "hl-notification-silencing-status",
    "on-click": "hl-toggle-notification-silencing",
    "return-type": "json",
    "interval": 5
  },

  "group/tray-expander": {
    "orientation": "inherit",
    "drawer": {
      "transition-duration": 600,
      "children-class": "tray-group-item"
    },
    "modules": ["custom/expand-icon", "tray"]
  },

  "custom/expand-icon": {
    "exec": "~/.config/waybar/scripts/tray-detect.sh",
    "return-type": "json",
    "interval": 5,
    "tooltip": false,
    "on-scroll-up": "",
    "on-scroll-down": "",
    "icon-size": 14
  },

  "tray": {
    "icon-size": 14,
    "spacing": 20
  },

  "bluetooth": {
    "format": "󰂯",
    "format-off": "󰂲",
    "format-disabled": "󰂲",
    "format-connected": "󰂱",
    "format-no-controller": "",
    "tooltip-format": "Devices connected: {num_connections}",
    "on-click": "hl-launch-bluetooth"
  },

  "network": {
    "format-icons": [""],
    "format": "{icon}",
    "format-wifi": "{icon}",
    "format-ethernet": "󰀂",
    "format-disconnected": "󰖪",
    "tooltip-format-wifi": "{essid} ({frequency} GHz)",
    "tooltip-format-ethernet": "Connected",
    "tooltip-format-disconnected": "Disconnected",
    "interval": 3,
    "on-click": "hl-launch-wifi"
  },

  "pulseaudio": {
    "format": "{icon}",
    "on-click": "hl-launch-audio",
    "on-click-right": "pamixer -t",
    "tooltip-format": "{volume}%",
    "scroll-step": 5,
    "format-muted": "",
    "format-icons": {
      "headphone": "",
      "headset": "",
      "default": ["", "", ""]
    }
  },

  "cpu": {
    "interval": 5,
    "format": "",
    "on-click": "hl-launch-tui btop"
  },

  "battery": {
    "format": "{capacity}% {icon}",
    "format-discharging": "{icon}",
    "format-charging":    "{icon}",
    "format-plugged":     "",
    "format-icons": {
      "charging": ["󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅"],
      "default":  ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"]
    },
    "format-full": "󰂅",
    "tooltip-format-discharging": "{power:>1.0f}W↓ {capacity}%",
    "tooltip-format-charging": "{power:>1.0f}W↑ {capacity}%",
    "interval": 5,
    "on-click": "hl-menu-system",
    "on-click-right": "notify-send -u low \"$(hl-battery-status)\"",
    "states": { "warning": 20, "critical": 10 }
  },

  "clock": {
    "format": " {:L%A %H:%M}",
    "format-alt": " {:L%d %B W%V %Y}",
    "tooltip": false
  }
}
EOF

# ── waybar/style.css ──────────────────────────────────────────────────────────
cat > "$CFG/waybar/style.css" <<'EOF'
/* ── Nord-inspired colour palette ───────────────────────────────────────────── */
@define-color foreground #d8dee9;
@define-color background #161616;

/* ── Reset ───────────────────────────────────────────────────────────────── */
* {
  border: none;
  border-radius: 0;
  min-height: 0;
  font-family: 'Inter Variable', 'JetBrainsMono Nerd Font', sans-serif;
  font-size: 14px;
  color: @foreground;
  background: transparent;
  font-weight: 600;
}

/* ── Bar: single glassy pill ─────────────────────────────────────────────── */
window#waybar {
  background: alpha(@background, 0.60);
  border-radius: 12px;
  color: @foreground;
}

.modules-left   { padding: 0 8px; }
.modules-center { padding: 0 14px; }
.modules-right  { padding: 0 8px; }

/* ── Launcher ────────────────────────────────────────────────────────────── */
#custom-launcher {
  min-width: 12px;
  margin: 0 4px 0 2px;
  font-size: 15px;
  opacity: 0.85;
}
#custom-launcher:hover { opacity: 1; }

/* ── Workspaces ──────────────────────────────────────────────────────────── */
#workspaces { padding: 0 2px; }

#workspaces button {
  all: initial;
  font-family: 'JetBrainsMono Nerd Font';
  font-size: 13px;
  color: @foreground;
  border-radius: 8px;
  padding: 0 6px;
  margin: 0 1px;
  min-width: 9px;
  opacity: 0.45;
  transition: opacity 150ms ease, color 150ms ease;
}
#workspaces button.active  { opacity: 1; }
#workspaces button.empty   { opacity: 0.2; }
#workspaces button:hover   { opacity: 0.8; }

/* ── Clock ───────────────────────────────────────────────────────────────── */
#clock {
  border-left: 1px solid alpha(@foreground, 0.15);
  margin-left: 6px;
  padding-left: 10px;
  padding-right: 4px;
  font-weight: 600;
  font-size: 14px;
  font-family: 'Inter Variable';
}

/* ── Media ───────────────────────────────────────────────────────────────── */
#mpris         { padding: 0 4px; opacity: 1; font-size: 14px; font-weight: 600; }
#mpris.paused  { opacity: 0.55; }
#mpris.stopped { min-width: 0; padding: 0; }

/* ── Right icons ─────────────────────────────────────────────────────────── */
.modules-right * { font-size: 16px; }

#custom-update    { margin: 0 9px; }
#custom-screenrecording,
#custom-idle,
#custom-dnd { min-width: 12px; margin: 0 7px; padding-bottom: 1px; }

#custom-screenrecording.active,
#custom-idle.active,
#custom-dnd.active { color: #bf616a; }

#custom-expand-icon { margin: 0 10px; }
#tray               { margin: 0 8px; }

#cpu        { min-width: 36px; }
#network    { min-width: 36px; }
#pulseaudio { min-width: 26px; }
#bluetooth  { min-width: 16px; font-size: 16px; margin-left: 4px; }
#battery    { min-width: 24px; }

#battery.warning  { color: #ebcb8b; }
#battery.critical { color: #bf616a; }

/* ── Tooltip ─────────────────────────────────────────────────────────────── */
tooltip {
  background: alpha(@background, 0.92);
  border: 1px solid alpha(@foreground, 0.12);
  padding: 4px 8px;
}
tooltip label { color: @foreground; }

menu, .menu, .context-menu { background: alpha(@background, 0.92); }
menuitem:hover, menuitem:focus { background: alpha(@foreground, 0.10); }

/* ── Hidden (used by tray expander) ──────────────────────────────────────── */
.hidden { opacity: 0; min-width: 0; padding: 0; margin: 0; }
EOF

success "Waybar config written."

# ── 8. WALKER CONFIG ─────────────────────────────────────────────────────────
step "Writing Walker config"

cat > "$CFG/walker/config.toml" <<'EOF'
force_keyboard_focus = true
selection_wrap       = true
theme                = "custom"
hide_action_hints    = true

[placeholders]
"default" = { input = "   Search...", list = "No Results" }

[keybinds]
quick_activate = []

[columns]
symbols = 1

[providers]
max_results = 256
default = [
  "desktopapplications",
  "websearch",
]

[[providers.prefixes]]
prefix   = "/"
provider = "providerlist"

[[providers.prefixes]]
prefix   = "."
provider = "files"

[[providers.prefixes]]
prefix   = ":"
provider = "symbols"

[[providers.prefixes]]
prefix   = "="
provider = "calc"

[[providers.prefixes]]
prefix   = "@"
provider = "websearch"

[[providers.prefixes]]
prefix   = "$"
provider = "clipboard"

[[emergencies]]
text    = "Restart Walker"
command = "pkill walker; walker &"
EOF

# Walker layout.xml (standalone copy of the default layout)
cat > "$CFG/walker/themes/custom/layout.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<interface>
  <requires lib="gtk" version="4.0"></requires>
  <object class="GtkWindow" id="Window">
    <style><class name="window"></class></style>
    <property name="resizable">true</property>
    <property name="title">Walker</property>
    <child>
      <object class="GtkBox" id="BoxWrapper">
        <style><class name="box-wrapper"></class></style>
        <property name="width-request">644</property>
        <property name="overflow">hidden</property>
        <property name="orientation">horizontal</property>
        <property name="valign">center</property>
        <property name="halign">center</property>
        <child>
          <object class="GtkBox" id="Box">
            <style><class name="box"></class></style>
            <property name="orientation">vertical</property>
            <property name="hexpand-set">true</property>
            <property name="hexpand">true</property>
            <property name="spacing">10</property>
            <child>
              <object class="GtkBox" id="SearchContainer">
                <style><class name="search-container"></class></style>
                <property name="overflow">hidden</property>
                <property name="orientation">horizontal</property>
                <property name="halign">fill</property>
                <property name="hexpand-set">true</property>
                <property name="hexpand">true</property>
                <child>
                  <object class="GtkEntry" id="Input">
                    <style><class name="input"></class></style>
                    <property name="halign">fill</property>
                    <property name="hexpand-set">true</property>
                    <property name="hexpand">true</property>
                  </object>
                </child>
              </object>
            </child>
            <child>
              <object class="GtkBox" id="ContentContainer">
                <style><class name="content-container"></class></style>
                <property name="orientation">horizontal</property>
                <property name="spacing">10</property>
                <property name="vexpand">true</property>
                <property name="vexpand-set">true</property>
                <child>
                  <object class="GtkLabel" id="Placeholder">
                    <style><class name="placeholder"></class></style>
                    <property name="label">No Results</property>
                    <property name="yalign">0.0</property>
                    <property name="hexpand">true</property>
                  </object>
                </child>
                <child>
                  <object class="GtkScrolledWindow" id="Scroll">
                    <style><class name="scroll"></class></style>
                    <property name="hexpand">true</property>
                    <property name="can_focus">false</property>
                    <property name="overlay-scrolling">true</property>
                    <property name="max-content-width">600</property>
                    <property name="max-content-height">300</property>
                    <property name="min-content-height">0</property>
                    <property name="propagate-natural-height">true</property>
                    <property name="propagate-natural-width">true</property>
                    <property name="hscrollbar-policy">automatic</property>
                    <property name="vscrollbar-policy">automatic</property>
                    <child>
                      <object class="GtkGridView" id="List">
                        <style><class name="list"></class></style>
                        <property name="max_columns">1</property>
                        <property name="can_focus">false</property>
                      </object>
                    </child>
                  </object>
                </child>
                <child>
                  <object class="GtkBox" id="Preview">
                    <style><class name="preview"></class></style>
                  </object>
                </child>
              </object>
            </child>
            <child>
              <object class="GtkLabel" id="Error">
                <style><class name="error"></class></style>
                <property name="xalign">0</property>
                <property name="visible">false</property>
              </object>
            </child>
          </object>
        </child>
      </object>
    </child>
  </object>
</interface>
EOF

# Walker theme CSS (self-contained, no Omarchy imports)
cat > "$CFG/walker/themes/custom/style.css" <<'EOF'
/* ── Nord-dark colour tokens ─────────────────────────────────────────────── */
@define-color text        #d8dee9;
@define-color base        #161616;
@define-color border      #d8dee9;
@define-color selected-text #3b4252;

/* ── Reset ───────────────────────────────────────────────────────────────── */
* { all: unset; }

* {
  font-family: 'Inter Variable', 'CaskaydiaMono Nerd Font', sans-serif;
  font-size: 15px;
  color: @text;
}

scrollbar { opacity: 0; }

/* ── Outer container ─────────────────────────────────────────────────────── */
.box-wrapper {
  background: alpha(@base, 0.60);
  border-radius: 16px;
  border: 2px solid alpha(@border, 0.18);
  padding: 10px;
}

/* ── Search bar ──────────────────────────────────────────────────────────── */
.search-container {
  background: alpha(@text, 0.06);
  border-radius: 10px;
  padding: 10px 14px;
  margin-bottom: 6px;
}

.input placeholder { opacity: 0.35; }

.input {
  font-size: 16px;
  font-weight: 500;
  caret-color: @selected-text;
}

.input:focus, .input:active { box-shadow: none; outline: none; }

/* ── Results list ────────────────────────────────────────────────────────── */
.content-container { padding: 2px 0; }

child {
  border-radius: 8px;
  transition: background 100ms ease;
  opacity: 0.8;
}
child:hover          { opacity: 0.7; }
child:hover .item-box { opacity: 1; }
child:selected       { background: alpha(@text, 0.07); opacity: 1; }

.item-box      { padding: 0 12px; }
.item-text-box { all: unset; padding: 10px 0; }
.item-text     { font-weight: 500; }
.item-subtext  { font-size: 12px; opacity: 0.5; margin-top: 1px; }
.item-image    { margin-right: 12px; -gtk-icon-transform: scale(0.88); }

/* ── Icons ───────────────────────────────────────────────────────────────── */
.normal-icons { -gtk-icon-size: 16px; }
.large-icons  { -gtk-icon-size: 28px; }

/* ── Misc ────────────────────────────────────────────────────────────────── */
.current     { font-style: normal; opacity: 0.6; }
.placeholder { opacity: 0.35; padding: 20px; }
EOF

success "Walker config written."

# ── 9. MAKO NOTIFICATION CONFIG ───────────────────────────────────────────────
step "Writing Mako config"

cat > "$CFG/mako/config" <<'EOF'
# ── Layout ────────────────────────────────────────────────────────────────────
anchor        = top-right
group-by      = app-name,summary,body
default-timeout = 5000
width         = 420
outer-margin  = 20
padding       = 10,15
border-size   = 1
max-icon-size = 32

# ── Colours (Nord dark) ───────────────────────────────────────────────────────
font             = Inter Variable 13px
text-color       = #d8dee9
border-color     = #3b425230
background-color = #16161699
border-radius    = 12

# ── Rules ─────────────────────────────────────────────────────────────────────
[app-name=Spotify]
invisible = 1

[mode=do-not-disturb]
invisible = true

[mode=do-not-disturb app-name=notify-send]
invisible = false

[urgency=critical]
default-timeout = 0
layer = overlay
EOF

success "Mako config written."

# ── 10. GHOSTTY TERMINAL CONFIG ───────────────────────────────────────────────
step "Writing Ghostty config"

cat > "$CFG/ghostty/config" <<'EOF'
# ── Colours (Nord dark) ───────────────────────────────────────────────────────
background        = #161616
foreground        = #d8dee9
cursor-color      = #d8dee9
selection-background = #5e81ac
selection-foreground = #eceff4

palette = 0=#161616
palette = 1=#bf616a
palette = 2=#a3be8c
palette = 3=#ebcb8b
palette = 4=#81a1c1
palette = 5=#b48ead
palette = 6=#88c0d0
palette = 7=#e5e9f0
palette = 8=#4c566a
palette = 9=#bf616a
palette = 10=#a3be8c
palette = 11=#ebcb8b
palette = 12=#81a1c1
palette = 13=#b48ead
palette = 14=#8fbcbb
palette = 15=#eceff4

# ── Font ──────────────────────────────────────────────────────────────────────
font-family    = "JetBrainsMono Nerd Font Mono"
font-style     = Regular
font-size      = 9

# ── Window ────────────────────────────────────────────────────────────────────
window-theme            = ghostty
window-padding-x        = 14
window-padding-y        = 14
confirm-close-surface   = false
resize-overlay          = never
gtk-toolbar-style       = flat

# ── Cursor ────────────────────────────────────────────────────────────────────
cursor-style       = block
cursor-style-blink = false
shell-integration-features = no-cursor,ssh-env

# ── Keybinds ──────────────────────────────────────────────────────────────────
keybind = shift+insert=paste_from_clipboard
keybind = control+insert=copy_to_clipboard

# ── Performance ───────────────────────────────────────────────────────────────
mouse-scroll-multiplier = 0.95
async-backend           = epoll
EOF

success "Ghostty config written."

# ── 11. SWAYOSD CONFIG ────────────────────────────────────────────────────────
step "Writing SwayOSD config"

cat > "$CFG/swayosd/style.css" <<'EOF'
window {
  background-color: alpha(#161616, 0.80);
  border-radius: 12px;
  border: 1px solid alpha(#d8dee9, 0.18);
}

#container {
  padding: 10px 14px;
  min-width: 180px;
}

label {
  color: #d8dee9;
  font-family: 'Inter Variable', sans-serif;
  font-size: 14px;
}

image {
  color: #d8dee9;
}

progressbar trough {
  border-radius: 4px;
  background-color: alpha(#d8dee9, 0.15);
  min-height: 6px;
}

progressbar progress {
  border-radius: 4px;
  background-color: #3b4252;
  min-height: 6px;
}
EOF

success "SwayOSD config written."

# ── 12. STARSHIP PROMPT ───────────────────────────────────────────────────────
step "Writing Starship prompt config"

cat > "$CFG/starship.toml" <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'

format = """
$directory\
$git_branch\
$git_state\
$git_status\
$cmd_duration\
$line_break\
$character"""

[directory]
style = "blue bold"
truncate_to_repo = true

[character]
success_symbol = "[❯](purple)"
error_symbol   = "[❯](red)"
vimcmd_symbol  = "[❮](green)"

[git_branch]
symbol    = " "
style     = "green"
format    = "[$symbol$branch]($style) "

[git_status]
style    = "yellow"

[cmd_duration]
min_time = 500
format   = "[$duration](yellow) "
EOF

success "Fallback configs written."
} # end _write_fallback_configs

# ── 8. WALLPAPER ──────────────────────────────────────────────────────────────
step "Setting up wallpaper"

# The dotfiles install sets up ~/.config/desktop/current/background from
# ~/.config/desktop/backgrounds/. If that symlink exists, swaybg will use it.
# We also keep the legacy wallpaper path as a fallback.
if [[ ! -L "$CFG/desktop/current/background" ]] && \
   [[ ! -f "$HOME/.local/share/backgrounds/wallpaper" ]]; then
    info "Generating a default dark wallpaper…"
    mkdir -p "$HOME/.local/share/backgrounds"
    convert -size 3840x2160 \
        gradient:'#0d1117-#1a1f2e' \
        "$HOME/.local/share/backgrounds/wallpaper.png" 2>/dev/null \
    && ln -sf "$HOME/.local/share/backgrounds/wallpaper.png" \
              "$HOME/.local/share/backgrounds/wallpaper" \
    || warn "ImageMagick unavailable — place an image at ~/.config/desktop/backgrounds/default-dark/"
fi

# ── 9. SHELL ENVIRONMENT ──────────────────────────────────────────────────────
step "Configuring shell environment"

SHELL_RC="$HOME/.bashrc"
append_once() {
    local marker="$1"; local block="$2"
    grep -qF "$marker" "$SHELL_RC" 2>/dev/null || printf '\n%s\n' "$block" >> "$SHELL_RC"
}

# If dotfiles/install ran, it already added the bash/rc source line.
# These are fallback aliases/evals for the case it didn't.
append_once 'source ~/.config/bash/rc' \
    '[[ $- == *i* ]] && source ~/.config/bash/rc'
append_once '# hl-desktop PATH' \
    'export PATH="$HOME/.local/bin:$PATH"'

success "Shell environment configured."

# ── 10. UWSM SESSION WRAP ────────────────────────────────────────────────────
step "Configuring UWSM"

mkdir -p "$CFG/uwsm"

# Write env as a FILE (not a directory) — sourced by uwsm at session start
if [[ ! -f "$CFG/uwsm/env" ]]; then
    cat > "$CFG/uwsm/env" <<'UWSMENV'
# Changes require a restart to take effect.

# Ensure user bins are in the path
export PATH=$HOME/.local/bin:$PATH

# Set default terminal and editor
source ~/.config/uwsm/default
UWSMENV
fi

if [[ ! -f "$CFG/uwsm/default" ]]; then
    cat > "$CFG/uwsm/default" <<'UWSMDEFAULT'
export TERMINAL=xdg-terminal-exec
export EDITOR=nvim
export SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
export SCREENRECORD_DIR="$HOME/Videos/Screencasts"
UWSMDEFAULT
fi

success "UWSM configured."

# ── DONE ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗"
echo -e "║          Desktop setup complete!                         ║"
echo -e "╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${BOLD}Next steps:${RESET}"
echo "  1. Adjust monitor config:   $CFG/hypr/monitors.conf"
echo "  2. Add wallpapers:          cp your-images ~/.config/desktop/backgrounds/default-dark/"
echo "  3. Reboot to start SDDM:    sudo systemctl reboot"
echo "  4. NVIDIA users:            Ensure $CFG/hypr/envs.conf has:"
echo "       env = NVD_BACKEND,direct"
echo "       env = LIBVA_DRIVER_NAME,nvidia"
echo "       env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
echo ""
echo -e "${BLUE}Helper scripts:${RESET}  $BIN_DIR/hl-*  (desktop controls)"
echo -e "${BLUE}Sys-* stubs:${RESET}    $BIN_DIR/sys-* (compatibility, replace later)"
echo -e "${BLUE}Update script:${RESET}  system-update"
echo ""
