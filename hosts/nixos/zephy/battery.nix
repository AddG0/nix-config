{_}: {
  # Reduce disk writes and enable laptop mode for longer battery life
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000;
    "vm.laptop_mode" = 5;
    "vm.dirty_ratio" = 95;
    "vm.dirty_background_ratio" = 60;
  };

  # Runtime profile switching — no rebuild needed
  #   powerprofilesctl set power-saver|balanced|performance
  #   asusctl profile -P Quiet|Balanced|Performance
  services.power-profiles-daemon.enable = true;

  # Limit charge to 80% to extend battery lifespan
  #   `charge-upto 100` to temporarily override
  hardware.asus.battery = {
    chargeUpto = 80;
    enableChargeUptoScript = true;
  };

  # Battery status reporting for desktop widgets
  services.upower.enable = true;

  # Auto-adjust brightness on AC/battery
  services.powerStateManager = {
    enable = true;
    onBattery.brightness = 40;
    onAC.brightness = 100;
  };
}
