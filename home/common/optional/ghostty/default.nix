{
  lib,
  pkgs,
  ...
}: {
  # stylix's ghostty target writes theme/font/opacity into these same settings.
  programs.ghostty = {
    enable = true;
    # ghostty has no darwin build in nix (the macOS app is built via Xcode).
    package =
      if pkgs.stdenv.hostPlatform.isDarwin
      then pkgs.ghostty-bin
      else pkgs.ghostty;

    settings = {
      # Ghostty only blurs on macOS and KDE; Hyprland does its own.
      background-blur = true;

      window-padding-color = "background";

      # Nix owns the version; macOS-only key, ignored elsewhere.
      auto-update = "off";

      # Snaps fg to black/white below the ratio, so keep it just under
      # catppuccin's dimmest text (1.80:1) or comments blow out to white.
      # 1.7 still catches pre-commit's bg-only green/red (1.03, 1.60).
      minimum-contrast = 1.7;

      # Monaspace puts its ligatures in stylistic sets; calt/liga alone give none.
      font-feature = ["calt" "liga" "ss01" "ss02" "ss03" "ss04" "ss05" "ss06" "ss07" "ss08" "ss09"];

      # Free ctrl+shift+arrow for tmux
      keybind =
        [
          "ctrl+shift+arrow_left=unbind"
          "ctrl+shift+arrow_right=unbind"
          "ctrl+shift+arrow_up=unbind"
          "ctrl+shift+arrow_down=unbind"
        ]
        # Command sits in the Linux Alt position; zsh's ghq, gwq and sesh pickers are Alt-G/W/S (ESC g/w/s).
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin ["super+g=esc:g" "super+w=esc:w" "super+s=esc:s"];
    };
  };

  # The macOS app only rereads its config on SIGUSR2.
  xdg.configFile."ghostty/config".onChange = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
    if /usr/bin/pgrep -xq ghostty; then run /usr/bin/pkill -USR2 -x ghostty; fi
  '';
}
