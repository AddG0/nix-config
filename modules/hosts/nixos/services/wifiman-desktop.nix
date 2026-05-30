{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.wifiman-desktop;
in {
  options.programs.wifiman-desktop = {
    enable = mkEnableOption "WiFiMan Desktop — installs the GUI and runs wifiman-desktopd as a root systemd service";

    package = mkOption {
      type = types.package;
      default = pkgs.wifiman-desktop;
      defaultText = literalExpression "pkgs.wifiman-desktop";
      description = "The wifiman-desktop package providing the GUI and the daemon binary.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    # The GUI is frontend-only — login, network scan, and Teleport WireGuard
    # tunnels all go through wifiman-desktopd on localhost:63150. Upstream's
    # .deb ships an equivalent unit at User=root.
    #
    # The daemon resolves its state file paths (service.json, log) from
    # os.Executable() — i.e. its own binary's directory — so it must run
    # from a writable place. We copy it into the StateDirectory at start
    # and symlink the immutable runtime assets (.env, wg, wg-quick,
    # wireguard-go, …) alongside it so they resolve relative to CWD.
    systemd.services.wifiman-desktopd = {
      description = "WiFiMan Desktop daemon";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      path = cfg.package.passthru.daemonRuntimeDeps;
      serviceConfig = {
        StateDirectory = "wifiman-desktopd";
        WorkingDirectory = "/var/lib/wifiman-desktopd";
        ExecStartPre = pkgs.writeShellScript "wifiman-desktopd-prepare" ''
          set -eu
          # Drop any package-managed symlinks so renamed/moved assets don't
          # linger. Real state files (service.json, *.log) are regular files
          # and not touched.
          find "$STATE_DIRECTORY" -maxdepth 1 -type l -delete
          assets=${cfg.package}/libexec/wifiman-desktop
          for f in "$assets"/* "$assets"/.[!.]*; do
            [ -e "$f" ] || continue
            ln -sfn "$f" "$STATE_DIRECTORY/$(basename "$f")"
          done
          # Fresh copy of the daemon binary into the writable StateDirectory
          # so os.Executable() inside the daemon resolves there.
          install -m 0755 ${lib.getExe' cfg.package "wifiman-desktopd"} \
            "$STATE_DIRECTORY/wifiman-desktopd"
        '';
        ExecStart = "/var/lib/wifiman-desktopd/wifiman-desktopd";
        Restart = "always";
        RestartSec = 30;
      };
    };
  };
}
