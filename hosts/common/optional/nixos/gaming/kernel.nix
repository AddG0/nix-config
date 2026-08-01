_: {
  boot.kernelModules = ["ntsync"]; # NT sync primitives for Wine/Proton

  # VMA headroom for Proton titles (e.g. Star Citizen); steam stops at 1048576.
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;

  # A few games hammer split locks; the mitigation throttles them bus-wide.
  boot.kernelParams = ["split_lock_detect=off"];
}
