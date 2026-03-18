{inputs, ...}: {
  imports = [
    ../common
    "${inputs.nix-secrets}/modules/shipperhq/hyprland"
    ./waybar.nix
    ./wofi.nix
    ./mako.nix
  ];
}
