{
  config,
  lib,
  pkgs,
  ...
}: {
  # TLP - Advanced Power Management for Linux
  # Official docs: https://linrunner.de/tlp/
  # Optimized for: AMD Ryzen 9 6900HX + NVIDIA GPU on ASUS ROG Zephyrus Duo 16

  # Kernel laptop-mode tweaks for better battery life
  boot.kernel.sysctl = {
    # Reduce disk write frequency (default: 500 = 5s, setting to 6000 = 60s)
    # Allows longer idle periods for disk/SSD power savings
    "vm.dirty_writeback_centisecs" = 6000;

    # Enable laptop mode - kernel optimizations for battery
    # Value of 5 seconds before considering system idle
    "vm.laptop_mode" = 5;

    # Additional VM tweaks for battery (aggressive settings for maximum savings)
    "vm.dirty_ratio" = 95;              # Start forced writeback at 95% RAM (max battery savings)
    "vm.dirty_background_ratio" = 60;   # Start background writeback at 60% RAM
  };

  services.tlp = {
    enable = true;

    settings = {
      # ==================== CPU Settings ====================

      # Processor frequency scaling for AMD Ryzen
      # "powersave" is recommended for battery - already your default
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # AMD-specific energy/performance policy
      # "power" is most aggressive for battery savings (was "balance_power")
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # AMD platform profile (Ryzen 6000 series support)
      # "low-power" focuses on power saving for battery
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # CPU boost - keep enabled on AC for performance
      # Disable on battery for power savings (can reduce performance)
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Limit max CPU frequency on battery for additional savings
      # Uncomment to cap CPU at 2.4 GHz on battery (saves 3-5W)
      # CPU_SCALING_MAX_FREQ_ON_BAT = 2400000;  # 2.4 GHz max

      # ==================== Battery Care ====================

      # Battery charge thresholds (ASUS-specific)
      # ASUS hardware limitation: Only accepts 60, 80, or 100
      # Charging to 80% dramatically extends battery lifespan

      # START threshold - ASUS may not support this (hardware limitation)
      # Use 0 as dummy value to skip
      START_CHARGE_THRESH_BAT0 = 0;

      # STOP threshold - Begin charging at this percentage
      # 80 = Optimal for daily use (2-3x longer battery life)
      # 60 = Maximum longevity (for mostly-plugged-in use)
      # 100 = No protection (reduces battery lifespan)
      STOP_CHARGE_THRESH_BAT0 = 80;

      # ==================== Runtime Power Management ====================

      # Enable runtime PM for PCI(e) devices
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # ==================== Graphics Power Management ====================

      # NVIDIA GPU is managed via hardware.nvidia.powerManagement in graphics.nix
      # TLP should not interfere with NVIDIA power management

      # ==================== Audio Power Management ====================

      # Audio power saving (timeout in seconds)
      SOUND_POWER_SAVE_ON_AC = 0;      # Disable on AC for better audio quality
      SOUND_POWER_SAVE_ON_BAT = 1;     # 1 second timeout on battery

      # ==================== Network Power Management ====================

      # WiFi power saving
      WIFI_PWR_ON_AC = "off";          # Max performance on AC
      WIFI_PWR_ON_BAT = "on";          # Power saving on battery

      # ==================== USB Power Management ====================

      # USB autosuspend - aggressive power saving
      USB_AUTOSUSPEND = 1;             # Enable autosuspend

      # Exclude USB devices that cause issues when suspended
      # Add device IDs if needed: "1234:5678 abcd:efgh"
      # USB_DENYLIST = "";

      # ==================== SATA/NVMe Power Management ====================

      # SATA aggressive link power management (ALPM)
      SATA_LINKPWR_ON_AC = "med_power_with_dipm";
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";

      # NVMe power management (for modern SSDs)
      AHCI_RUNTIME_PM_ON_AC = "on";
      AHCI_RUNTIME_PM_ON_BAT = "auto";

      # ==================== PCIe Power Management ====================

      # PCIe Active State Power Management (ASPM)
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # ==================== Kernel Settings ====================

      # Laptop mode - kernel optimizer for battery
      NMI_WATCHDOG = 0;                # Disable NMI watchdog (saves power)

      # ==================== Misc Settings ====================

      # Restore charge thresholds on reboot
      RESTORE_THRESHOLDS_ON_BAT = 1;

      # Verbose logging for troubleshooting (disable for production)
      # TLP_DEBUG = "bat disk lock nm path pm ps rf run sysfs udev usb";
    };
  };

  # Power Profiles Daemon conflicts with TLP
  # TLP provides more granular control
  services.power-profiles-daemon.enable = lib.mkForce false;

  # Unified Power State Manager - Declarative AC/battery mode configuration
  services.powerStateManager = {
    enable = true;

    # Universal settings (work on any system)
    onBattery.brightness = 40;   # 40% brightness on battery
    onAC.brightness = 100;        # Full brightness on AC

    # KDE backend for display management
    kde = {
      enable = true;
      onBattery = {
        refreshRate = 60;   # 60Hz on battery (saves ~2-4W)
        modeNumber = 2;     # Hard-coded for instant switching
      };
      onAC = {
        refreshRate = 165;  # Max refresh rate on AC
        modeNumber = 1;     # Hard-coded for instant switching
      };
    };

    # ASUS backend for performance profiles
    asus = {
      enable = true;
      onBattery.profile = "Quiet";      # Quiet mode on battery
      onAC.profile = "Balanced";         # Balanced mode on AC
    };
  };
}
