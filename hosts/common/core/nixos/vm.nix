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
      qemu.options = ["-vga none" "-device virtio-vga-gl" "-display gtk,gl=on"];
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
    # The VM has its own host key, so the sops password can't decrypt.
    users.users.${config.hostSpec.primaryUsername} = {
      hashedPasswordFile = lib.mkVMOverride null;
      initialPassword = lib.mkVMOverride "vm";
    };
  };
}
