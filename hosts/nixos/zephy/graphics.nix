{
  pkgs,
  inputs,
  config,
  ...
}: {
  # https://medium.com/@notquitethereyet_/gaming-on-nixos-%EF%B8%8F-f98506351a24

  imports = [
    inputs.hardware.nixosModules.common-gpu-nvidia
    "${inputs.hardware}/common/gpu/nvidia/ampere"
  ];

  hardware.nvidia = {
    powerManagement.enable = true;
    powerManagement.finegrained = true; # Enable dynamic power management

    prime = {
      amdgpuBusId = "PCI:6:0:0"; # AMD Radeon 680M (integrated)
      nvidiaBusId = "PCI:1:0:0"; # NVIDIA RTX 3080 Ti (discrete)
    };
  };

  # hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
