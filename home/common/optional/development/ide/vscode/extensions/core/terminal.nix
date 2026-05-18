{lib, ...}: {
  extensions = [];
  userSettings = {
    # Terminal settings
    "terminal.integrated.defaultProfile.linux" = "zsh";
    # Disable the integrated terminal exit alert because the zsh code 130 message was annoying since I run exit and it shows up.
    "terminal.integrated.showExitAlert" = false;
    "terminal.integrated.profiles.linux" = {
      "nushell" = {
        "path" = "nu";
      };
      "bash" = {
        "path" = "bash";
        "icon" = "terminal-bash";
      };
    };
    "terminal.integrated.fontFamily" = lib.mkForce "'JetBrainsMono Nerd Font Mono'";
    "terminal.integrated.fontSize" = lib.mkForce 14;
    "terminal.integrated.cursorStyle" = "line";
    "terminal.integrated.cursorBlinking" = true;
    "terminal.integrated.smoothScrolling" = true;
    "terminal.integrated.scrollback" = 10000;
    "terminal.integrated.initialHint" = false;
  };
  # Free Ctrl+G in the terminal so it reaches the shell (fzf-git uses it as a prefix),
  # and expose Go to Recent Directory on Ctrl+G everywhere else.
  keybindings = [
    {
      key = "ctrl+g";
      command = "-workbench.action.terminal.goToRecentDirectory";
    }
    {
      key = "ctrl+g";
      command = "workbench.action.terminal.goToRecentDirectory";
      when = "!terminalFocus";
    }
  ];
}
