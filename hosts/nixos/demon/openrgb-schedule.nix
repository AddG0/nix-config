# OpenRGB day/night schedule, per-user: lights off overnight, "Primary" profile
# by day. Runs in the logged-in user's session (at login + the schedule times),
# so it uses that user's own ~/.config/OpenRGB/Primary.orp.
{
  config,
  pkgs,
  ...
}: let
  # 24h "HH:MM"; window wraps midnight (off from offTime until onTime next day).
  offTime = "20:30";
  onTime = "07:30";

  hhmm = t: builtins.replaceStrings [":"] [""] t; # "07:30" -> "0730" (10#… below dodges octal)
  calendar = t: "*-*-* ${t}:00";

  # Plain local apply, NOT --client: an SDK-client `-p` load reports success
  # but never pushes to the daemon's devices; only a local apply takes effect.
  openrgb = "${config.services.hardware.openrgb.package}/bin/openrgb";
  apply = pkgs.writeShellScript "openrgb-apply-schedule" ''
    now=$((10#$(${pkgs.coreutils}/bin/date +%H%M)))
    if [ "$now" -ge $((10#${hhmm offTime})) ] || [ "$now" -lt $((10#${hhmm onTime})) ]; then
      # real Off mode persists after the client exits; -c 000000 (Direct color)
      # reverts on Aura/ENE gear. Direct-only devices (Wooting) just warn + skip.
      ${openrgb} -m off
    elif [ -f "$HOME/.config/OpenRGB/Primary.orp" ]; then
      ${openrgb} -p Primary
    else
      echo "openrgb-schedule: no $HOME/.config/OpenRGB/Primary.orp; leaving lights as-is" >&2
    fi
  '';
in {
  systemd.user.services.openrgb-schedule = {
    description = "Apply OpenRGB day/night lighting schedule";
    after = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = apply;
    };
  };

  systemd.user.timers.openrgb-schedule = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = [(calendar onTime) (calendar offTime)];
      Persistent = true;
    };
  };
}
