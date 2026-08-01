# demon gaming/performance tuning (9950X3D + RTX 5090).
{pkgs, ...}: {
  # LTO + znver4 march over the generic shared default (CachyOS groups Zen5 under zen4).
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-zen4;

  # V-cache is on only one CCD, but the driver defaults to `frequency` (biases the
  # other, higher-clocking CCD); games want `cache`, and Linux does no automatic
  # game-aware CCD parking. Oneshot not a udev rule: the driver binds before udevd
  # coldplug, so a `bind`-action rule wouldn't fire.
  systemd.services.amd-x3d-cache-mode = {
    description = "Bias AMD 3D V-Cache scheduling to the cache CCD";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for f in /sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode; do
        echo cache > "$f"
      done
    '';
  };
}
