#
# Razer Blade 16 (2025) — macro key remaps
#
# The five M-keys on the right side of the keyboard each emit something
# unhelpful out of the box on Linux:
#
#   M1 → KEY_PAGEUP        (firmware default — usable as-is)
#   M2 → KEY_PAGEDOWN      (firmware default — usable as-is)
#   M3 → KEY_UNKNOWN       (HID 0x700d5 from the Keyboard Reserved range)
#   M4 → KEY_UNKNOWN       (HID 0x700d3 from the Keyboard Reserved range)
#   M5 → Meta+Alt+K chord  (Microsoft Teams mic-mute hotkey)
#
# Vendor=1532 Product=02E0 = "Razer Razer Blade Keyboard".
{
  config,
  lib,
  ...
}: {
  # M3/M4 are single proprietary scancodes the kernel can't name. Remap them
  # to F13/F14 via udev hwdb so anything (Hyprland, etc.) can bind them.
  services.udev.extraHwdb = ''
    evdev:input:b0003v1532p02E0*
     KEYBOARD_KEY_700d5=f13
     KEYBOARD_KEY_700d3=f14
  '';

  # M5 fires a real 3-key HID chord, not a single scancode, so hwdb can't
  # help. Have keyd absorb the chord on the Razer Blade and emit F15 instead,
  # keeping M3/M4/M5 → F13/F14/F15 consistent. keyd matches the most-specific
  # id and doesn't cascade across entries, so we extend the shared default
  # settings rather than redefine them — capslock=esc keeps living in the
  # shared keyd.nix and is inherited here.
  services.keyd.keyboards.razer-blade = {
    ids = ["1532:02e0"];
    settings = lib.recursiveUpdate config.services.keyd.keyboards.default.settings {
      "meta+alt".k = "f15";
    };
  };
}
