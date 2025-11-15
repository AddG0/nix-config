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
    powerManagement.enable = true;
    powerManagement.finegrained = true; # Enable dynamic power management

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
