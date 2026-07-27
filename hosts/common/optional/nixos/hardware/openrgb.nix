# OpenRGB daemon + udev/i2c access for RGB control.
# For motherboard SMBus RGB (e.g. ASUS Aura), set per-host:
#   services.hardware.openrgb.motherboard = "amd"; # or "intel"
_: {
  services.hardware.openrgb.enable = true;
}
