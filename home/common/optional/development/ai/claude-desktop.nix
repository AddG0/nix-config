{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux (let
  # Focus Claude then send Ctrl+Alt+Space to trigger Quick Entry
  claude-quick-entry = pkgs.writeShellScript "claude-quick-entry" ''
    hyprctl dispatch focuswindow "class:^(Claude)$"
    sleep 0.1
    hyprctl dispatch sendshortcut "CTRL ALT,space,class:^(Claude)$"
  '';
in {
  home.packages = [
    pkgs.claude-desktop
  ];

  wayland.windowManager.hyprland.settings = lib.mkIf config.wayland.windowManager.hyprland.enable {
    bind = [
      "ALT,space,exec,${claude-quick-entry}"
    ];
    windowrule = [
      "stay_focused on, match:class ^(Claude)$, match:title ^$"
      "pin on, match:class ^(Claude)$, match:title ^$"
    ];
  };
})
