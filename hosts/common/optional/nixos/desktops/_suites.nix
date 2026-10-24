{optional, ...}:
with optional.hosts.nixos.desktops; {
  hyprland.nixos = [hyprland];
  niri.nixos = [niri];
  plasma6.nixos = [plasma6];
}
