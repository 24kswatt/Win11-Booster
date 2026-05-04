#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Arch Linux zero install
# UEFI + ext4 + systemd-boot + Hyprland base
# Run from Arch live ISO.
# ============================================================

RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

log() {
  echo -e "\n${GREEN}==>${RESET} $*"
}

warn() {
  echo -e "\n${YELLOW}[WARN]${RESET} $*"
}

die() {
  echo -e "\n${RED}[ERR]${RESET} $*" >&2
  exit 1
}

[[ "$(id -u)" -eq 0 ]] || die "Lancia lo script come root dalla live ISO Arch."

[[ -d /sys/firmware/efi/efivars ]] || die "Non sei in UEFI mode. Riavvia la USB in modalità UEFI."

log "Dischi disponibili"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL

echo
read -rp "Disco da usare, esempio /dev/sda oppure /dev/nvme0n1: " DISK
[[ -b "$DISK" ]] || die "Disco non valido: $DISK"

echo
warn "STAI PER CANCELLARE TUTTO QUESTO DISCO:"
lsblk "$DISK"
echo
read -rp "Username da creare: " USERNAME
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Username non valido."

echo
read -rsp "Password per root e utente $USERNAME: " USERPASS
echo
[[ -n "$USERPASS" ]] || die "Password vuota non consentita."

echo
warn "Ultima sicurezza: tra 8 secondi cancello $DISK. CTRL+C per annullare."
sleep 8

HOSTNAME="archbox"
SWAP_SIZE="+16G"

log "Setup tastiera italiana e orario"
loadkeys it || true
timedatectl set-ntp true

log "Aggiorno keyring live ISO"
pacman -Sy --noconfirm archlinux-keyring

log "Pulizia eventuali mount precedenti"
swapoff -a || true
umount -R /mnt 2>/dev/null || true

log "Partizionamento disco $DISK"

sgdisk --zap-all "$DISK"

sgdisk -n 1:0:+1G       -t 1:ef00 -c 1:"EFI"       "$DISK"
sgdisk -n 2:0:${SWAP_SIZE} -t 2:8200 -c 2:"swap"      "$DISK"
sgdisk -n 3:0:0         -t 3:8300 -c 3:"arch-root" "$DISK"

partprobe "$DISK"
sleep 2

if [[ "$DISK" =~ (nvme|mmcblk) ]]; then
  EFI="${DISK}p1"
  SWAP="${DISK}p2"
  ROOT="${DISK}p3"
else
  EFI="${DISK}1"
  SWAP="${DISK}2"
  ROOT="${DISK}3"
fi

log "Partizioni create"
lsblk "$DISK"

log "Formatto partizioni"
mkfs.fat -F32 "$EFI"
mkswap "$SWAP"
swapon "$SWAP"
mkfs.ext4 -F "$ROOT"

log "Monto filesystem"
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$EFI" /mnt/boot

log "Rilevo microcode CPU"
if grep -qi "GenuineIntel" /proc/cpuinfo; then
  MICROCODE="intel-ucode"
  MICROCODE_IMG="intel-ucode.img"
else
  MICROCODE="amd-ucode"
  MICROCODE_IMG="amd-ucode.img"
fi

echo "Microcode: $MICROCODE"

log "Installo Arch base + Hyprland stack"

pacstrap -K /mnt \
  base linux linux-firmware "$MICROCODE" \
  base-devel sudo \
  networkmanager wpa_supplicant \
  pipewire wireplumber pipewire-pulse pipewire-alsa \
  xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  hyprland xorg-xwayland \
  waybar fuzzel kitty \
  qt5-wayland qt6-wayland \
  pavucontrol pamixer alsa-utils libpulse \
  swaync swww hyprlock hypridle \
  grim slurp swappy wf-recorder \
  wl-clipboard cliphist \
  thunar thunar-archive-plugin file-roller tumbler gvfs udiskie \
  polkit-kde-agent \
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd \
  papirus-icon-theme adwaita-cursors nwg-look \
  git neovim vim nano \
  lazygit tmux fzf ripgrep fd eza bat zoxide starship btop jq \
  curl wget unzip zip \
  man-db man-pages texinfo bash-completion \
  efibootmgr

log "Genero fstab"
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab

log "Configuro sistema dentro chroot"

arch-chroot /mnt /bin/bash <<EOF
set -euo pipefail

ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc

sed -i 's/^#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=it_IT.UTF-8" > /etc/locale.conf
echo "KEYMAP=it" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
HOSTS

useradd -m -G wheel -s /bin/bash "$USERNAME"

echo "root:$USERPASS" | chpasswd
echo "$USERNAME:$USERPASS" | chpasswd

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

systemctl enable NetworkManager
systemctl enable fstrim.timer

systemctl --global enable pipewire.service
systemctl --global enable pipewire-pulse.service
systemctl --global enable wireplumber.service

bootctl install
EOF

log "Creo systemd-boot entry"

ROOT_UUID="$(blkid -s UUID -o value "$ROOT")"

cat > /mnt/boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

cat > /mnt/boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /$MICROCODE_IMG
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw
EOF

log "Creo config Hyprland per $USERNAME"

USER_HOME="/mnt/home/$USERNAME"

mkdir -p \
  "$USER_HOME/.config/hypr" \
  "$USER_HOME/.config/fuzzel" \
  "$USER_HOME/.config/waybar" \
  "$USER_HOME/.config/kitty" \
  "$USER_HOME/Pictures/Screenshots"

cat > "$USER_HOME/.config/hypr/hyprland.conf" <<'EOF'
$mod = SUPER
$terminal = kitty
$launcher = fuzzel

monitor=,preferred,auto,1

exec-once = waybar
exec-once = swaync
exec-once = swww-daemon
exec-once = udiskie --tray
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = /usr/lib/polkit-kde-authentication-agent-1

env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland;xcb
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1
env = ELECTRON_OZONE_PLATFORM_HINT,auto

bind = $mod, RETURN, exec, $terminal
bind = $mod, D, exec, $launcher
bind = $mod, Q, killactive
bind = $mod, F, fullscreen
bind = $mod, M, exit
bind = $mod, L, exec, hyprlock

bind = $mod SHIFT, S, exec, grim -g "$(slurp)" "$HOME/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png"
bind = $mod, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
bind = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t
bind = , XF86AudioMicMute, exec, pamixer --default-source -t

bind = $mod, h, movefocus, l
bind = $mod, l, movefocus, r
bind = $mod, k, movefocus, u
bind = $mod, j, movefocus, d

bind = $mod SHIFT, h, movewindow, l
bind = $mod SHIFT, l, movewindow, r
bind = $mod SHIFT, k, movewindow, u
bind = $mod SHIFT, j, movewindow, d

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

cat > "$USER_HOME/.config/fuzzel/fuzzel.ini" <<'EOF'
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

cat > "$USER_HOME/.config/waybar/config" <<'EOF'
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

cat > "$USER_HOME/.config/waybar/style.css" <<'EOF'
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

cat > "$USER_HOME/.config/kitty/kitty.conf" <<'EOF'
font_family JetBrainsMono Nerd Font
font_size 11.0
background_opacity 0.92
confirm_os_window_close 0
enable_audio_bell no
copy_on_select yes
shell_integration enabled
EOF

cat > "$USER_HOME/.bash_profile" <<'EOF'
if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
  exec Hyprland
fi
EOF

cat > "$USER_HOME/.bashrc" <<'EOF'
eval "$(starship init bash)"
eval "$(zoxide init bash)"

alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --group-directories-first'
alias cat='bat'
alias grep='grep --color=auto'

export EDITOR=nvim
EOF

arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

log "Installazione completata"
echo
echo "Bootloader entry:"
cat /mnt/boot/loader/entries/arch.conf
echo

log "Smonto tutto"
umount -R /mnt
swapoff "$SWAP"

echo
echo -e "${GREEN}FATTO.${RESET}"
echo
echo "Ora puoi fare:"
echo "  reboot"
echo
echo "Poi togli la USB, fai login con utente '$USERNAME'."
echo "Dopo il login su tty1 partirà Hyprland automaticamente."