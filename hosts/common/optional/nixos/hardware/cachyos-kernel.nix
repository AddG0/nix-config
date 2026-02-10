# CachyOS Kernel - Optimized Linux kernel for desktop performance
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
{pkgs, ...}: {
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;

  # Binary cache for prebuilt CachyOS kernels
  nix.settings = {
    substituters = ["https://attic.xuyh0120.win/lantian"];
    trusted-public-keys = ["lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="];
  };
}
