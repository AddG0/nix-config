_: {
  # Force AMD iGPU to high performance mode for better Plasma performance
  # The AMD Radeon 680M was throttling in auto mode, causing sluggish UI
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff" # Enable all power features
  ];

  # Set AMD GPU to high performance mode via udev rule
  services.udev.extraRules = ''
    KERNEL=="card2", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="high"
  '';
}
