_: {
  # niri-flake's module and the package pin live in hosts/common/core/nixos/niri.nix.
  programs.niri.enable = true;

  services.greetd.desktops.niri = "niri-session";
}
