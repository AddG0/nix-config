# Motherboard SMBus RGB (e.g. ASUS Aura) is host-specific; set in the host:
#   services.hardware.openrgb.motherboard = "amd"; # or "intel"
_: {
  services.hardware.openrgb.enable = true;
}
