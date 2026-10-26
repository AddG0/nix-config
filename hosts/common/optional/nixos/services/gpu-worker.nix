# Runs asgard's GPU jobs as rootless podman containers under their own user.
{
  config,
  lib,
  ...
}: {
  # NVIDIA exposes its GPUs through CDI; AMD and Intel are reached through /dev/dri and /dev/kfd.
  hardware.nvidia-container-toolkit.enable = lib.elem "nvidia" config.services.xserver.videoDrivers;

  virtualisation.podman.enable = true;

  users.groups.gpu-worker = {};
  users.users.gpu-worker = {
    isSystemUser = true;
    group = "gpu-worker";
    extraGroups = ["render" "video"];
    home = "/var/lib/gpu-worker";
    createHome = true;
    # Rootless podman needs subordinate ids, which system users don't get automatically.
    subUidRanges = [
      {
        startUid = 300000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 300000;
        count = 65536;
      }
    ];
    # Keeps /run/user/<uid> and the user manager up with nobody logged in.
    linger = true;
  };
}
