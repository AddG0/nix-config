_: {
  imports = [
    ../common
    ./visuals.nix
    ./noctalia.nix
    ./stylix-noctalia-compat.nix # delete when upstream stylix supports noctalia v5
    # ./anyrun.nix
    ./walker.nix
    ./pip.nix
    ./hyprlock.nix
    ./wallpaper-defaults.nix
  ];
}
