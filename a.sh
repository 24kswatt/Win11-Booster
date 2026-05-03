#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Arch Hyprland bootstrap
# Pacman-only, no AUR.
# Stack:
# Hyprland + Waybar + Fuzzel + Kitty + SwayNC + PipeWire
# ============================================================

log() {
  printf "\n\033[1;32m==>\033[0m %s\n" "$*"
}

warn() {
  printf "\n\033[1;33m[WARN]\033[0m %s\n" "$*"
}

die() {
  printf "\n\033[1;31m[ERR]\033[0m %s\n" "$*" >&2
  exit 1
}

if [[ "$(id -u)" -eq 0 ]]; then
  die "Non lanciarlo come root. Lancialo dal tuo utente normale con sudo configurato."
fi

if ! command -v pacman >/dev/null 2>&1; then
  die "Questo script è pensato per Arch Linux / pacman."
fi

if ! sudo -v; then
  die "sudo non disponibile o password errata."
fi

log "Aggiorno sistema e installo pacchetti base Hyprland"

packages=(
  hyprland
  xorg-xwayland

  waybar
  fuzzel
  kitty

  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk

  qt5-wayland
  qt6-wayland

  pipewire
  wireplumber
  pipewire-pulse
  pipewire-alsa
  pavucontrol
  pamixer

  swaync
  swww
  hyprlock
  hypridle

  grim
  slurp
  swappy
  wf-recorder

  wl-clipboard
  cliphist

  thunar
  thunar-archive-plugin
  file-roller
  tumbler
  gvfs
  udiskie

  polkit-kde-agent

  noto-fonts
  noto-fonts-emoji
  ttf-jetbrains-mono-nerd
  papirus-icon-theme
  adwaita-cursors
  nwg-look

  git
  neovim
  lazygit
  tmux
  fzf
  ripgrep
  fd
  eza
  bat
  zoxide
  starship
  btop
  jq
  curl
  wget
  unzip
  zip
)

sudo pacman -Syu --needed "${packages[@]}"

log "Abilito servizi base"

sudo systemctl enable --now NetworkManager || warn "NetworkManager non abilitato, controlla manualmente."

systemctl --user daemon-reload || true
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service || warn "PipeWire user services non avviati, magari partiranno al prossimo login."

log "Creo cartelle config"

mkdir -p \
  "$HOME/.config/hypr" \
  "$HOME/.config/fuzzel" \
  "$HOME/.config/waybar" \
  "$HOME/.config/kitty" \
  "$HOME/.config/swaync" \
  "$HOME/Pictures/Screenshots"

backup_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local bak="${file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$file" "$bak"
    warn "Backup creato: $bak"
  fi
}

log "Scrivo hyprland.conf minimale"

backup_file "$HOME/.config/hypr/hyprland.conf"

cat > "$HOME/.config/hypr/hyprland.conf" <<'EOF'
# ============================================================
# Hyprland minimal config
# SUPER + ENTER      terminale
# SUPER + D          launcher
# SUPER + Q          chiudi finestra
# SUPER + M          esci da Hyprland
# SUPER + SHIFT + S  screenshot area
# ============================================================

$mod = SUPER
$terminal = kitty
$launcher = fuzzel

monitor=,preferred,auto,1

# Autostart
exec-once = waybar
exec-once = swaync
exec-once = swww-daemon
exec-once = udiskie --tray
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = /usr/lib/polkit-kde-authentication-agent-1

# Env sane per Wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_QPA_PLATFORMTHEME,qt5ct
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1

# App
bind = $mod, RETURN, exec, $terminal
bind = $mod, D, exec, $launcher
bind = $mod, Q, killactive
bind = $mod, F, fullscreen
bind = $mod, M, exit
bind = $mod, L, exec, hyprlock

# Screenshot / clipboard
bind = $mod SHIFT, S, exec, grim -g "$(slurp)" "$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"
bind = $mod, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

# Audio
bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
bind = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioMicMute, exec, pamixer --default-source -t

# Focus vim-style
bind = $mod, h, movefocus, l
bind = $mod, l, movefocus, r
bind = $mod, k, movefocus, u
bind = $mod, j, movefocus, d

# Move windows
bind = $mod SHIFT, h, movewindow, l
bind = $mod SHIFT, l, movewindow, r
bind = $mod SHIFT, k, movewindow, u
bind = $mod SHIFT, j, movewindow, d

# Workspaces
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9

bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
bind = $mod SHIFT, 6, movetoworkspace, 6
bind = $mod SHIFT, 7, movetoworkspace, 7
bind = $mod SHIFT, 8, movetoworkspace, 8
bind = $mod SHIFT, 9, movetoworkspace, 9

# Mouse
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

general {
    gaps_in = 5
    gaps_out = 12
    border_size = 2
    layout = dwindle
}

decoration {
    rounding = 12

    blur {
        enabled = true
        size = 6
        passes = 2
    }

    shadow {
        enabled = true
        range = 12
        render_power = 3
    }
}

animations {
    enabled = true
}

input {
    kb_layout = it
    follow_mouse = 1

    touchpad {
        natural_scroll = true
    }
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}
EOF

log "Scrivo config fuzzel"

backup_file "$HOME/.config/fuzzel/fuzzel.ini"

cat > "$HOME/.config/fuzzel/fuzzel.ini" <<'EOF'
[main]
terminal=kitty
width=45
lines=12
horizontal-pad=18
vertical-pad=12
inner-pad=8
font=JetBrainsMono Nerd Font:size=11
prompt="❯ "
layer=overlay

[colors]
background=11111bee
text=cdd6f4ff
match=89b4faff
selection=313244ff
selection-text=cdd6f4ff
border=89b4faff

[border]
width=2
radius=12
EOF

log "Scrivo config Waybar"

backup_file "$HOME/.config/waybar/config"
backup_file "$HOME/.config/waybar/style.css"

cat > "$HOME/.config/waybar/config" <<'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 34,
  "spacing": 8,

  "modules-left": [
    "hyprland/workspaces",
    "hyprland/window"
  ],

  "modules-center": [
    "clock"
  ],

  "modules-right": [
    "pulseaudio",
    "network",
    "memory",
    "cpu",
    "tray"
  ],

  "hyprland/workspaces": {
    "format": "{name}",
    "persistent-workspaces": {
      "*": 5
    }
  },

  "hyprland/window": {
    "format": "{}",
    "max-length": 60
  },

  "clock": {
    "format": "{:%H:%M}",
    "tooltip-format": "{:%A %d %B %Y}"
  },

  "pulseaudio": {
    "format": "VOL {volume}%",
    "format-muted": "MUTE",
    "on-click": "pavucontrol"
  },

  "network": {
    "format-wifi": "NET {essid}",
    "format-ethernet": "ETH",
    "format-disconnected": "NO NET",
    "tooltip-format": "{ifname} - {ipaddr}"
  },

  "memory": {
    "format": "RAM {}%"
  },

  "cpu": {
    "format": "CPU {usage}%"
  },

  "tray": {
    "spacing": 10
  }
}
EOF

cat > "$HOME/.config/waybar/style.css" <<'EOF'
* {
  border: none;
  border-radius: 0;
  font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
  font-size: 13px;
  min-height: 0;
}

window#waybar {
  background: rgba(17, 17, 27, 0.86);
  color: #cdd6f4;
}

#workspaces {
  margin-left: 8px;
}

#workspaces button {
  padding: 0 10px;
  margin: 5px 3px;
  border-radius: 999px;
  color: #a6adc8;
  background: rgba(49, 50, 68, 0.75);
}

#workspaces button.active {
  color: #11111b;
  background: #89b4fa;
}

#window,
#clock,
#pulseaudio,
#network,
#memory,
#cpu,
#tray {
  padding: 0 12px;
  margin: 5px 3px;
  border-radius: 999px;
  background: rgba(49, 50, 68, 0.75);
}

#clock {
  color: #89b4fa;
}

#pulseaudio {
  color: #a6e3a1;
}

#network {
  color: #f9e2af;
}

#memory,
#cpu {
  color: #cba6f7;
}
EOF

log "Scrivo config Kitty minimale"

backup_file "$HOME/.config/kitty/kitty.conf"

cat > "$HOME/.config/kitty/kitty.conf" <<'EOF'
font_family JetBrainsMono Nerd Font
font_size 11.0

background_opacity 0.92
confirm_os_window_close 0

enable_audio_bell no
copy_on_select yes

shell_integration enabled
EOF

log "Configuro shell quality-of-life"

if ! grep -q 'starship init bash' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'EOF'

# Modern shell helpers
eval "$(starship init bash)"
eval "$(zoxide init bash)"

alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first'
alias cat='bat'
alias grep='grep --color=auto'
EOF
fi

log "Check servizi"

systemctl is-enabled NetworkManager >/dev/null 2>&1 && echo "NetworkManager enabled: OK" || echo "NetworkManager enabled: NO"
systemctl --user is-active pipewire >/dev/null 2>&1 && echo "PipeWire active: OK" || echo "PipeWire active: NO"
systemctl --user is-active wireplumber >/dev/null 2>&1 && echo "WirePlumber active: OK" || echo "WirePlumber active: NO"

log "Installazione completata"

cat <<'EOF'

Prossimi step:

1. Da TTY lancia:
   Hyprland

2. Keybind:
   SUPER + ENTER      terminale
   SUPER + D          launcher
   SUPER + Q          chiudi finestra
   SUPER + M          esci
   SUPER + SHIFT + S  screenshot
   SUPER + V          clipboard history

3. Se Waybar non parte:
   waybar

4. Se audio non va:
   wpctl status
   pavucontrol

5. Se vuoi riavviare:
   sudo reboot

EOF