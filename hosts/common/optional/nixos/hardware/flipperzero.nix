{config, ...}: {
  hardware.flipperzero.enable = true;

  # qFlipper udev rule sets GROUP="dialout"; uaccess tag is unreliable
  # because the rule matches the USB parent (SUBSYSTEMS==) rather than
  # the device node, so group membership is the reliable access path.
  users.users.${config.hostSpec.username}.extraGroups = ["dialout"];
}
