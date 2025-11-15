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
    prime = {
      amdgpuBusId = "PCI:6:0:0"; # Correct the format to include the full structure
      nvidiaBusId = "PCI:1:0:0";
    };
    # We can't enable this since zephyrus's main monitor only works from the nvidia card
    primeBatterySaverSpecialisation = false;
  };

  # hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
