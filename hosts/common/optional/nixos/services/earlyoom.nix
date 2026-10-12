{
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
  };

  # earlyoom waits for swap to run out, and a large swapfile thrashes long before that.
  systemd.oomd.enableUserSlices = true;
}
