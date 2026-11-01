{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [ghostty])
  ];

  # Plain Zen; the browsers module is the configured one.
  home.packages = [inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta];

  programs.plasma = {
    enable = true;
    workspace.lookAndFeel = "org.kde.breezedark.desktop";
  };
}
