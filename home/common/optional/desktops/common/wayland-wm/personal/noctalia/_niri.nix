{
  config,
  lib,
  ...
}: let
  noctalia = lib.getExe config.programs.noctalia.package;
  msg = args: {action.spawn = [noctalia "msg"] ++ args;};
in {
  programs.niri.settings.binds = {
    "Mod+C" = msg ["panel-toggle" "control-center" "calendar"];
    "Mod+N" = msg ["panel-toggle" "control-center" "notifications"];
    # The mute cue comes from mic-mute-sound, which reacts to any mute change.
    "Mod+M" = msg ["mic-mute"];

    # Volume, mic, media and brightness keys go through Noctalia for its OSD.
    "XF86AudioRaiseVolume" = msg ["volume-up"];
    "XF86AudioLowerVolume" = msg ["volume-down"];
    "XF86AudioMute" = msg ["volume-mute"];
    "XF86AudioMicMute" = msg ["mic-mute"];
    "XF86AudioPlay" = msg ["media" "toggle"];
    "XF86AudioPause" = msg ["media" "toggle"];
    "XF86AudioNext" = msg ["media" "next"];
    "XF86AudioPrev" = msg ["media" "previous"];
    "XF86AudioStop" = msg ["media" "stop"];
    "XF86MonBrightnessUp" = msg ["brightness-up"];
    "XF86MonBrightnessDown" = msg ["brightness-down"];
  };
}
