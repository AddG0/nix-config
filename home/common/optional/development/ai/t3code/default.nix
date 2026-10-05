{
  config,
  lib,
  pkgs,
  ...
}: let
  claudeProfiles = config.programs.claude-code-profiles;
  claudeProfileDir = "${config.home.homeDirectory}/${claudeProfiles.profiles.${claudeProfiles.defaultProfile}.profileDir}";

  # Threads spawn the CLI at the repo with no shell between, so chpwd never fires.
  inDirectoryEnv = exe: lib.getExe (config.programs.directoryEnv.wrap exe);
  codexForT3 = pkgs.writeShellScriptBin "codex" ''
    export XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome}
    exec ${inDirectoryEnv (lib.getExe' config.programs.codex.package "codex")} "$@"
  '';
  runtimeDir = ".t3/runtime/versions/${config.programs.t3code.package.version}";
in {
  # The desktop's SSH launch always runs this pinned runtime, else downloads a glibc build NixOS cannot exec.
  home.file = {
    "${runtimeDir}/t3".source = lib.getExe' config.programs.t3code.package "t3";
    "${runtimeDir}/.install-complete".text = config.programs.t3code.package.version;
  };

  imports = [
    ./keybindings.nix
    ./package.nix
    ./sync-projects
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
      # suppressed by overlays/common/development/t3code/update-banner.nix.
      #
      # Each points at the same build the shell gets, so t3code inherits the
      # telemetry wrappers and the code-assistant-profiles content.
      providerInstances = {
        codex = {
          driver = "codex";
          config.binaryPath = lib.getExe codexForT3;
        };
        claudeAgent = {
          driver = "claudeAgent";
          # The profile wrapper, not the packaged CLI: homePath only exports
          # CLAUDE_CONFIG_DIR; the MCP servers and plugins arrive as wrapper flags.
          config = {
            binaryPath = inDirectoryEnv (lib.getExe' claudeProfiles.wrapperPackage "claude");
            # Usage and skill discovery both scan under homePath; empty resolves
            # to ~/.claude, which the profile layout leaves unused.
            homePath = claudeProfileDir;
          };
        };
        opencode = {
          driver = "opencode";
          # Since 0.0.38 the opencode driver defaults off; without this it probes as "disabled".
          enabled = true;
          config.binaryPath = inDirectoryEnv (lib.getExe' config.programs.opencode.package "opencode");
        };
      };
    };
  };
}
