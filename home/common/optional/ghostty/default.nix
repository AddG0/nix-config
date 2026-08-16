{pkgs, ...}: {
  # stylix's ghostty target writes theme/font/opacity into these same settings.
  programs.ghostty = {
    enable = true;
    # ghostty has no darwin build in nix (the macOS app is built via Xcode).
    package =
      if pkgs.stdenv.hostPlatform.isDarwin
      then pkgs.ghostty-bin
      else pkgs.ghostty;

    settings = {
      window-padding-color = "background";

      # Monaspace puts its ligatures in stylistic sets; calt/liga alone give none.
      font-feature = ["ss01" "ss02" "ss03" "ss04" "ss05" "ss06" "ss07" "ss08" "ss09"];

      # Free ctrl+shift+arrow for tmux
      keybind = [
        "ctrl+shift+arrow_left=unbind"
        "ctrl+shift+arrow_right=unbind"
        "ctrl+shift+arrow_up=unbind"
        "ctrl+shift+arrow_down=unbind"
      ];
    };
  };
}
