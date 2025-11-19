{
  pkgs,
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
    powerManagement.finegrained = true;

    prime = {
      amdgpuBusId = "PCI:6:0:0"; # AMD Radeon 680M (integrated)
      nvidiaBusId = "PCI:1:0:0"; # NVIDIA RTX 3080 Ti (discrete)
    };

    primeBatterySaverSpecialisation = true;
  };

  # hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Default: Set GPU to Hybrid mode (NVIDIA available when needed)
  services.supergfxd.settings.mode = lib.mkDefault "Hybrid";

  # Specialisation: Battery-saver mode with integrated GPU only
  specialisation.battery-saver.configuration = lib.mkIf config.hardware.nvidia.primeBatterySaverSpecialisation {
    system.nixos.tags = ["battery-saver" "integrated-only"];

    # Force Integrated GPU mode on boot
    services.supergfxd.settings.mode = lib.mkForce "Integrated";
  };
}
