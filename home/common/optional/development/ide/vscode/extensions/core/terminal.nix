_: {
  extensions = [];
  userSettings = {
    # Terminal settings
    "terminal.integrated.defaultProfile.linux" = "zsh";
    "terminal.integrated.profiles.linux" = {
      "nushell" = {
        "path" = "nu";
      };
      "bash" = {
        "path" = "bash";
        "icon" = "terminal-bash";
      };
    };
    "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font Mono'";
    "terminal.integrated.fontSize" = 14;
    "terminal.integrated.cursorStyle" = "line";
    "terminal.integrated.cursorBlinking" = true;
    "terminal.integrated.smoothScrolling" = true;
    "terminal.integrated.scrollback" = 10000;
  };
}
