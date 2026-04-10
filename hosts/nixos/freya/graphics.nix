{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [
    "${inputs.hardware}/common/gpu/nvidia/blackwell"
  ];

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Save/restore GPU state across suspend/resume to prevent post-resume
    # flip timeout crashes (seen after long suspends with s2idle).
    powerManagement.enable = true;
    # Allow NVIDIA GPU to fully power down at runtime when idle.
    # Requires modesetting (already set via nvidia-drm.modeset=1).
    powerManagement.finegrained = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Specialisation: iGPU-only battery saver mode.
  # Completely removes the NVIDIA dGPU at boot — no modules loaded,
  # PCI device removed via udev, Hyprland uses Intel xe only.
  # Boot into "battery-saver" from the bootloader to activate.
  # Reboot back to default to restore NVIDIA.
  specialisation.battery-saver.configuration = {
    system.nixos.tags = ["battery-saver" "integrated-only"];

    # Blacklist all NVIDIA kernel modules
    boot.blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
    ];

    # Remove NVIDIA PCI devices at boot via udev — actually powers off the GPU
    services.udev.extraRules = ''
      # Remove NVIDIA USB xHCI Host Controller
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA USB Type-C UCSI
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA Audio
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA VGA/3D controller
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
    '';

    # Disable NVIDIA power management hooks (not needed without the GPU)
    hardware.nvidia.powerManagement.enable = lib.mkForce false;
    hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
  };
}
