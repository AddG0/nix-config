{optional, ...}:
with optional.hosts.nixos.desktops; {
  hyprland.nixos = [common hyprland];
  niri.nixos = [common niri];
  plasma6.nixos = [common plasma6];
}
