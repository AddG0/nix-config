{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: {
  # https://medium.com/@notquitethereyet_/gaming-on-nixos-%EF%B8%8F-f98506351a24

  imports = [
    inputs.hardware.nixosModules.common-gpu-nvidia
  ];

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # # https://wiki.hyprland.org/Nvidia/
  # boot.kernelParams = [
  #   "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  #   # Since NVIDIA does not load kernel mode setting by default,
  #   # enabling it is required to make Wayland compositors function properly.
  #   "nvidia-drm.fbdev=1"
  # ];

  # boot.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

  # boot.extraModprobeConfig = ''
  #   options nvidia_drm modeset=1
  # '';

  # hardware.nvidia = {
  #   open = true;
  #   prime = {
  #     offload = {
  #       enable = false;
  #     };

  #     nvidiaBusId = "PCI:1:0:0";
  #   };
  #   powerManagement.enable = false;
  #   modesetting.enable = true;
  # };

  # hardware.nvidia-container-toolkit.enable = true;
  # hardware.graphics = {
  #   enable = true;
  #   # needed by nvidia-docker
  #   enable32Bit = true;
  #   extraPackages = with pkgs; [
  #     vaapiVdpau
  #     libvdpau-va-gl
  #   ];
  # };

  # services.supergfxd.enable = true;

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    prime = {
      sync.enable = false;
      offload.enable = false;
    };

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
