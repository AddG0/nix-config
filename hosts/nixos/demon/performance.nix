# demon gaming/performance tuning (9950X3D + RTX 5090).
{pkgs, ...}: {
  # LTO + znver4 march over the generic shared default (CachyOS groups Zen5 under zen4).
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-zen4;

  # 9950X3D is dual-CCD and BORE isn't CCD/cache-aware; scx_lavd is latency- and
  # LLC-aware, so it keeps game threads on the V-cache CCD.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  boot.kernel.sysctl = {
    # Headroom for VMA-hungry Proton titles (e.g. Star Citizen) above the 1048576 default.
    "vm.max_map_count" = 2147483642;
  };

  # A few games hammer split locks; the mitigation throttles them bus-wide.
  boot.kernelParams = ["split_lock_detect=off"];

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
