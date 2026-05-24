#
# GPU Screen Recorder replay buffer.
#
# Importing hosts must set `services.gpu-screen-recorder.display` (e.g.
# `"portal"` to capture via xdg-desktop-portal — recommended for HDR/10-bit
# monitors since direct capture there produces oversaturated colors) and
# typically `matchMonitorName` so the smart xdph picker can auto-select the
# right monitor without showing a dialog.
# https://wiki.hyprland.org/Configuring/Monitors/#10-bit-support
#
_: {
  services.gpu-screen-recorder = {
    enable = true;
    postRecordSeconds = 10;
  };
}
