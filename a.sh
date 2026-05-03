#!/usr/bin/env bash
set -euo pipefail

sudo pacman -Syu --needed \
  hyprland xorg-xwayland \
  waybar tofi kitty \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  qt5-wayland qt6-wayland \
  pavucontrol pamixer \
  swaync swww hyprlock hypridle \
  grim slurp swappy wf-recorder \
  wl-clipboard cliphist \
  thunar thunar-archive-plugin file-roller tumbler gvfs udiskie \
  polkit-kde-agent \
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd \
  papirus-icon-theme bibata-cursor-theme nwg-look \
  lazygit tmux fzf ripgrep fd eza bat zoxide starship btop jq