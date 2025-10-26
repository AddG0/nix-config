{
  pkgs,
  inputs,
  ...
}: {
  # https://medium.com/@notquitethereyet_/gaming-on-nixos-%EF%B8%8F-f98506351a24

  imports = [
    inputs.hardware.nixosModules.common-gpu-nvidia
  ];

  # https://wiki.hyprland.org/Nvidia/
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    # Since NVIDIA does not load kernel mode setting by default,
    # enabling it is required to make Wayland compositors function properly.
    "nvidia-drm.fbdev=1"
  ];

  boot.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

  boot.extraModprobeConfig = ''
    options nvidia_drm modeset=1
  '';

  hardware.nvidia = {
    open = false;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # Lets you use `nvidia-offload %command%` in steam
      };

      amdgpuBusId = "PCI:6:0:0"; # Correct the format to include the full structure
      nvidiaBusId = "PCI:1:0:0";
    };
    powerManagement.enable = false;
    modesetting.enable = true;
  };

  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    # needed by nvidia-docker
    enable32Bit = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  services.supergfxd.enable = true;

  services.xserver.videoDrivers = ["nvidia"];
}
