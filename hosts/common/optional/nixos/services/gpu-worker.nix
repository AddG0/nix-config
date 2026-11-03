# Runs dev-cloud's GPU Jobs on this host; enroll it once with `sudo gpu-worker-enroll <join string>`.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  busyFile = config.services.dev-cloud.gpu-worker.desktopBusyFile;

  # Holds the busy file exactly while GameMode has a client, so no Job takes the GPU from a game.
  gameGuard = pkgs.writeShellApplication {
    name = "gpu-worker-game-guard";
    runtimeInputs = [pkgs.glib pkgs.coreutils pkgs.gnugrep];
    text = ''
      game_active() {
        local out
        out=$(gdbus call --session \
          --dest com.feralinteractive.GameMode \
          --object-path /com/feralinteractive/GameMode \
          --method org.freedesktop.DBus.Properties.Get \
          com.feralinteractive.GameMode ClientCount 2>/dev/null) || return 1
        # gdbus prints the variant between angle brackets, e.g. "(<2>,)".
        [[ "$out" =~ \<([0-9]+)\> ]] && [ "''${BASH_REMATCH[1]}" -gt 0 ]
      }

      reconcile() {
        if game_active; then
          touch ${busyFile}
        else
          rm -f ${busyFile}
        fi
      }

      # Cleared only on a deliberate stop: after a crash the file stays until the restart's reconcile.
      trap 'rm -f ${busyFile}; exit 0' TERM

      # Catch a game already running, then wake on ClientCount changes and on gamemoded restarts, which reset it silently.
      reconcile
      gdbus monitor --session \
        --dest com.feralinteractive.GameMode \
        --object-path /com/feralinteractive/GameMode 2>/dev/null \
        | grep --line-buffered -E 'PropertiesChanged.*ClientCount|is owned by|does not have an owner' \
        | while IFS= read -r _; do reconcile; done
    '';
  };
in {
  imports = [inputs.dev-cloud.nixosModules.gpu-worker];

  config = lib.mkMerge [
    {
      services.dev-cloud.gpu-worker.enable = true;

      # Jobs reach NVIDIA GPUs through CDI.
      hardware.nvidia-container-toolkit.enable = lib.elem "nvidia" config.services.xserver.videoDrivers;
    }

    (lib.mkIf config.programs.gamemode.enable {
      # In the gpu-worker group, so their session's guard can write the busy file.
      users.users = lib.genAttrs config.hostSpec.users (_: {extraGroups = ["gpu-worker"];});

      systemd.user.services.gpu-worker-game-guard = {
        description = "Keep the dev-cloud GPU worker off the GPU while a game runs";
        after = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        wantedBy = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = lib.getExe gameGuard;
          # A session-bus hiccup can end gdbus monitor cleanly, which would silently stop the guard.
          Restart = "always";
          RestartSec = 5;
        };
      };
    })
  ];
}
