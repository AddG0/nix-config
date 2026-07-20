# Wacom Intuos Pro dial-scroll config. Output mode is deliberately absent — it's
# switched imperatively by the noctalia otd-mode widget. Needs the OTD daemon
# (hosts/.../nixos/hardware/opentabletdriver.nix) enabled on the host.
_: {
  programs.opentabletdriver.tablets."Wacom PTK-670" = {
    dials.left = {scroll = "vertical";};
    dials.right = {scroll = "horizontal";};
  };
}
