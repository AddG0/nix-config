{inputs, ...}: {
  imports = [
    "${inputs.nix-secrets}/modules/shipperhq/hyprland"
    ./waybar.nix
    ./wofi.nix
    ./mako.nix
    ./_hyprland.nix
  ];
}
