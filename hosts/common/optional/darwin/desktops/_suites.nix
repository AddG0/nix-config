{optional, ...}:
with optional.hosts.darwin.desktops; {
  macos.nixos = with macos; [karabiner];
}
