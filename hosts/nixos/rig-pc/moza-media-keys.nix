# MOZA wheel d-pad as music controls for the primary user: left/right skip tracks, up toggles play/pause.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Codes are from a press-test on the R3.
  mediaButtons = {
    "btn:base2" = "previous"; # left
    "btn:pinkie" = "next"; # right
    "btn:top2" = "play-pause"; # up
  };

  # No grab, so games still see every press; evsieve only listens.
  evsieveArgs =
    ["--input" "/dev/input/moza-wheel"]
    ++ lib.concatLists (lib.mapAttrsToList (button: action: ["--hook" button "exec-shell=${pkgs.playerctl}/bin/playerctl ${action}"]) mediaButtons);
in {
  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_VENDOR_ID}=="346e", ENV{ID_INPUT_JOYSTICK}=="1", SYMLINK+="input/moza-wheel", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="moza-media-keys.service"
  '';

  # A user service so playerctl reaches the session's player over its D-Bus.
  systemd.user.services.moza-media-keys = {
    description = "MOZA wheel d-pad -> media controls (evsieve)";
    bindsTo = ["dev-input-moza\\x2dwheel.device"];
    after = ["dev-input-moza\\x2dwheel.device"];
    unitConfig.ConditionUser = config.hostSpec.primaryUsername;
    # The wheel opens only while this user holds the seat (uaccess); until then it keeps retrying.
    startLimitIntervalSec = 0;
    serviceConfig = {
      ExecStart = "${pkgs.evsieve}/bin/evsieve ${lib.escapeShellArgs evsieveArgs}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
