{
  inputs,
  config,
  lib,
  ...
}: {
  # https://medium.com/@notquitethereyet_/gaming-on-nixos-%EF%B8%8F-f98506351a24

  imports = [
    inputs.hardware.nixosModules.common-gpu-nvidia
    "${inputs.hardware}/common/gpu/nvidia/ampere"
  ];

  # Default configuration: Hybrid mode (NVIDIA available when needed)
  hardware.nvidia = {
    # Use open-source NVIDIA drivers for better power management
    # Specifically added to fix errors around closing the laptop lid erroring, preventing the displays from loading back up correctly
    open = true;
    powerManagement.enable = true;
    # Disabled: RTD3 cannot suspend the dGPU while it drives displays (DP-2, HDMI-A-1).
    # Causes GL_INNOCENT_CONTEXT_RESET → Hyprland crash + safe-mode fallback.
    powerManagement.finegrained = false;

    prime = {
      amdgpuBusId = "PCI:6:0:0"; # AMD Radeon 680M (integrated)
      nvidiaBusId = "PCI:1:0:0"; # NVIDIA RTX 3080 Ti (discrete)
    };

    primeBatterySaverSpecialisation = true;
  };

  # finegrained=false just omits the modprobe option, leaving the Ampere default (0x03 = fine-grained).
  # Explicitly disable RTD3 since external monitors are wired through the dGPU.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';

  # hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Default: Set GPU to Hybrid mode (NVIDIA available when needed)
  services.supergfxd.settings.mode = lib.mkDefault "Hybrid";

  # Hybrid: AMD iGPU as primary compositor, NVIDIA for its connected displays
  environment.sessionVariables = {
    AQ_DRM_DEVICES = "/dev/dri/card2:/dev/dri/card1";
    # Disable explicit sync on multi-GPU buffers to prevent
    # "Explicit sync failed" → GL_INNOCENT_CONTEXT_RESET crashes.
    AQ_MGPU_NO_EXPLICIT = "1";
  };

  # Specialisation: Battery-saver mode with integrated GPU only
  specialisation.battery-saver.configuration = lib.mkIf config.hardware.nvidia.primeBatterySaverSpecialisation {
    system.nixos.tags = ["battery-saver" "integrated-only"];

    # Force Integrated GPU mode on boot
    services.supergfxd.settings.mode = lib.mkForce "Integrated";
    environment.sessionVariables.AQ_DRM_DEVICES = lib.mkForce "/dev/dri/card2";
  };
}
