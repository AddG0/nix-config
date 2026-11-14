# demon RAM pressure: zram swap, and /tmp kept on disk and self-cleaning.
{
  # zswap would intercept pages before they reach zram (CachyOS kernel enables it by default)
  boot.kernelParams = ["zswap.enabled=0"];

  # Sized to RAM as CachyOS does: the cap is uncompressed, zstd lands near 3:1.
  zramSwap = {
    enable = true;
    memoryPercent = 100;
    priority = 100;
  };

  # ArchWiki/Pop!_OS zram tuning: swapping to RAM is cheaper than refetching evicted file cache.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };

  boot.tmp.cleanOnBoot = true;
  # Agent runs leave GBs of scratch dirs a day; systemd's stock /tmp age is 10d.
  environment.etc."tmpfiles.d/tmp.conf".text = ''
    Q /tmp 1777 root root 3d
    q /var/tmp 1777 root root 30d
  '';
}
