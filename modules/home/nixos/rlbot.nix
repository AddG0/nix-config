# RLBot v5 for Rocket League. See pkgs/rlbot for the packages.
#
# RLBot starts the game itself, via the Proton shim below. Nothing here touches
# a normal Steam launch, so BakkesMod is not loaded during a bot match.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.rlbot;

  appId = "252950"; # Rocket League
  # null without the steam-config module; every use below guards for it.
  compatToolName = config.programs.steam.config.apps.${appId}.compatTool or null;
  compatToolLink = "Steam/compatibilitytools.d/${compatToolName}";
in {
  options.programs.rlbot = {
    enable = lib.mkEnableOption "RLBot v5, the Rocket League bot framework";
    package = lib.mkPackageOption pkgs "rlbot" {};
    serverPackage = lib.mkPackageOption pkgs "rlbot-server" {};
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # Core exits once its last client disconnects, so the GUI outlives it and
    # the next match fails to reconnect; Restart brings it back mid-session.
    # Not auto-started - the rlbot command owns it, so nothing runs at idle.
    systemd.user.services.rlbot-server = {
      Unit = {
        Description = "RLBotServer (RLBot v5 match server)";
        PartOf = ["graphical-session.target"];
        # Every match end is a clean exit, so the default 5-in-10s rate limit
        # measures normal use and would strand the unit in `failed`.
        StartLimitIntervalSec = 0;
      };
      Service = {
        ExecStart = lib.getExe cfg.serverPackage;
        Restart = "always";
        RestartSec = 1;
      };
    };

    warnings = lib.optional (compatToolName == null) ''
      programs.rlbot: no steam-config entry for app ${appId}, so no compatibility
      tool could be republished for RLBot. Core will fall back to stock Proton,
      which cannot run on NixOS.
    '';

    assertions = [
      {
        assertion = compatToolName == null || config.xdg.dataFile ? ${compatToolLink};
        message = "programs.rlbot: no compatibilitytools.d entry for '${toString compatToolName}' to republish.";
      }
    ];

    # Core only scans steamapps/common, so the compatibilitytools.d entry is
    # invisible to it; see pkgs/rlbot/proton-shim.nix.
    xdg.dataFile = lib.mkIf (compatToolName != null) {
      "Steam/steamapps/common/Proton-RLBot".source = pkgs.rlbot-proton-shim.override {
        inherit compatToolName;
        proton = config.xdg.dataFile.${compatToolLink}.source;
      };
    };
  };
}
