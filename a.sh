sudo pacman -Syu --needed \
  discord firefox chromium \
  pipewire wireplumber pipewire-pulse pipewire-alsa \
  xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  pavucontrol pamixer libpulse alsa-utils && \
systemctl --user daemon-reload && \
systemctl --user enable --now pipewire pipewire-pulse wireplumber && \
systemctl --user restart pipewire pipewire-pulse wireplumber xdg-desktop-portal xdg-desktop-portal-hyprland