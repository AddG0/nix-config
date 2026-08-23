{
  config,
  lib,
  ...
}: {
  imports = [
    ./keybindings.nix
    ./nvim.nix
    ./theme.nix
  ];

  programs.t3code = {
    enable = true;

    userSettings = {
      # Otherwise the browser opens at ~/, a long walk to a nested subgroup.
      addProjectBaseDirectory = config.polyrepo.ghqRoot;

      # Already upstream's default; pinned so a flip there cannot quietly start
      # creating worktrees. New threads only — the composer still picks per thread.
      defaultThreadEnvMode = "local";

      # Any binaryPath containing a separator makes t3code treat the CLI as
      # manually managed, removing the one-click update button (it only knows how
      # to run npm/brew/pnpm). The separate "update available" banner is
      # suppressed by the overlay in overlays/common/development/t3code.nix.
      #
      # Each points at the same build the shell gets, so t3code inherits the
      # telemetry wrappers and the code-assistant-profiles content.
      providerInstances = {
        codex = {
          driver = "codex";
          config.binaryPath = lib.getExe' config.programs.codex.package "codex";
        };
        claudeAgent = {
          driver = "claudeAgent";
          # The profile wrapper, not the packaged CLI: it passes the profile's
          # --mcp-config and --plugin-dir as flags on top of CLAUDE_CONFIG_DIR,
          # so t3code's own homePath setting would still drop the MCP servers
          # and plugins.
          config.binaryPath = lib.getExe' config.programs.claude-code-profiles.wrapperPackage "claude";
        };
        opencode = {
          driver = "opencode";
          config.binaryPath = lib.getExe' config.programs.opencode.package "opencode";
        };
      };
    };
  };
}
