{
  pkgs,
  lib,
  ...
}: let
  # Hyprland has no global pad remap and Qt's Wayland pad support is unreliable, so
  # evsieve drives the pad entirely: dials -> scroll, express keys -> shortcuts, via
  # separate virtual devices that work in every app. btn codes are from a press-test.
  evsieveArgs = [
    "--input /dev/input/wacom-pad grab"

    "--map btn:3 key:rightbrace" # left pad, top: brush size up
    "--map btn:2 key:leftbrace" # left pad, bottom: brush size down
    "--map btn:1 key:leftctrl key:z" # left pad, left: undo
    "--map btn:0 key:leftctrl key:leftshift key:z" # left pad, right: redo
    "--map btn:7 key:leftctrl" # right pad, top: Ctrl (Krita color picker)
    "--map btn:4 key:space" # right pad, bottom: pan
    "--map btn:6 key:leftshift" # right pad, left: Shift
    "--map btn:5 key:e" # right pad, right: eraser toggle

    "--block abs" # drop the dial mode indicator

    "--output rel:x rel:y rel:wheel rel:hwheel rel:wheel_hi_res rel:hwheel_hi_res btn:left name=wacom-dial-scroll"
    "--output key name=wacom-pad-keys"
  ];
in {
  # LIBINPUT_IGNORE_DEVICE keeps Hyprland from seeing the pad at all (otherwise it
  # interprets the express keys as button events). evsieve opens the evdev node
  # directly, so it still reads the dials and buttons.
  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Wacom Intuos Pro M Pad", SYMLINK+="input/wacom-pad", ENV{LIBINPUT_IGNORE_DEVICE}="1", TAG+="systemd", ENV{SYSTEMD_WANTS}="wacom-dial-scroll.service"
  '';

  # Bound to the pad's device unit, so it starts when the tablet is plugged in
  # and stops when it's removed (no restart-spam when absent).
  systemd.services.wacom-dial-scroll = {
    description = "Wacom pad dials -> scroll + express keys -> shortcuts (evsieve)";
    bindsTo = ["dev-input-wacom\\x2dpad.device"];
    after = ["dev-input-wacom\\x2dpad.device"];
    serviceConfig = {
      ExecStart = "${pkgs.evsieve}/bin/evsieve ${lib.concatStringsSep " " evsieveArgs}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
