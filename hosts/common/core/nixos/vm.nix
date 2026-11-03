# `just vm`: the host in a QEMU window, sized for a desktop and reachable by ssh on port 2222.
{
  config,
  lib,
  ...
}: {
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 4;
      diskSize = 20480;
      # The store DB lives on the disk image, so VM-built paths must persist with it.
      writableStoreUseTmpfs = false;
      # `just vm --disk-size` grows the image; this grows the filesystem to match.
      fileSystems."/".autoResize = true;
      # Not gtk: its grab never confines the pointer on Wayland (qemu#2225).
      qemu.options = ["-vga none" "-device virtio-vga-gl" "-display sdl,gl=on"];
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };
    # virgl reports GL 4.2; Ghostty needs 4.3 and runs fine claiming it.
    environment.sessionVariables = {
      MESA_GL_VERSION_OVERRIDE = "4.3";
      MESA_GLSL_VERSION_OVERRIDE = "430";
    };
    # keyd spins at 100% CPU here and never reads the grabbed virtio keyboard.
    services.keyd.enable = lib.mkVMOverride false;
    # Its loadModels pull tens of GB on first boot.
    services.ollama.enable = lib.mkVMOverride false;
    # qemu-vm drops swapDevices but not this, so the initrd waits forever for the host's real disk.
    boot.resumeDevice = lib.mkVMOverride "";
    # The VM has its own host key, so no sops secret can decrypt.
    hostSpec.disableSops = lib.mkVMOverride true;
    users.users.${config.hostSpec.primaryUsername}.initialPassword = lib.mkVMOverride "vm";
  };
}
