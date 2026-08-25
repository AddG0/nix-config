# CachyOS Kernel + userspace tuning - Optimized for desktop performance
#
# Features:
# - BORE (Burst-Oriented Response Enhancer) scheduler for better responsiveness
# - Optimized for desktop/gaming workloads
# - Better CPU utilization and lower latency
#
# Available variants (in pkgs.cachyosKernels):
# - linuxPackages-cachyos-latest      (latest stable with BORE)
# - linuxPackages-cachyos-lts         (LTS version)
# - linuxPackages-cachyos-bore        (explicit BORE scheduler)
# - linuxPackages-cachyos-hardened    (security-focused)
# - linuxPackages-cachyos-server      (server optimized)
# - *-lto variants                    (with Link Time Optimization)
#
# CPU-specific optimizations (append to variant name):
# - x86-64-v3: For Haswell+ (AVX2) - most modern CPUs
# - x86-64-v4: For Skylake-X+ (AVX-512)
# - zen4: For AMD Zen4/Zen5 CPUs (Ryzen 7000/9000 series)
# Generic BORE build by default; hosts may override with a march/LTO variant
# (e.g. demon pins -lto-zen4). Don't force a march here — freya is Intel.
{
  pkgs,
  lib,
  ...
}: {
  boot.kernelPackages = lib.mkDefault pkgs.cachyosKernels.linuxPackages-cachyos-bore;

  # BORE isn't topology- or LLC-aware (hybrid P/E, dual-CCD V-cache); scx_lavd
  # keeps latency-critical game threads on the fast cores.
  #
  # FLAKE-UPDATE: scx 1.1.3 vs kernel 7.2.0 sched_ext ABI skew drops lavd's
  # starvation-rescue knobs; the watchdog then kills the scheduler every few
  # minutes, stalling xhci long enough to drop USB HID. Re-enable once resynced.
  services.scx = {
    enable = lib.mkDefault false;
    scheduler = lib.mkDefault "scx_lavd";
    # Autopilot, the default, core-compacts: it packs threads onto fewer cores.
    extraArgs = ["--performance"];
  };

  # Auto-renice launched games above background tasks; pairs with scx (scx picks
  # the core, ananicy sets priority/ioclass).
  services.ananicy = {
    enable = lib.mkDefault true;
    package = pkgs.ananicy-cpp;
    # FLAKE-UPDATE: drop once the nixos module's rulesProvider default stops
    # pointing at the removed pkgs.ananicy (nixpkgs#541881 dropped the package
    # but not the module defaults). Re-check after `nix flake update`.
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };
}
