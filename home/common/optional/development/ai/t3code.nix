{
  lib,
  pkgs,
  ...
}: {
  programs.t3code = {
    enable = true;

    # Absolute /nix/store paths make t3code treat these CLIs as externally
    # managed, removing the one-click update button (it only knows how to run
    # npm/brew/pnpm). The separate "update available" banner is suppressed by the
    # overlay in overlays/development/t3code.nix.
    userSettings.providerInstances = {
      codex = {
        driver = "codex";
        config.binaryPath = lib.getExe pkgs.codex;
      };
      claudeAgent = {
        driver = "claudeAgent";
        config.binaryPath = lib.getExe pkgs.claude-code;
      };
      opencode = {
        driver = "opencode";
        config.binaryPath = lib.getExe pkgs.opencode;
      };
    };
  };
}
