_: {
  # niri-flake's module and the package pin live in hosts/common/core/nixos/niri.nix.
  programs.niri.enable = true;

  desktops.sessions.niri = {
    displayName = "Niri";
    desktopNames = ["niri"];
    command = "niri-session";
    stop = "niri msg action quit --skip-confirmation";
  };
}
