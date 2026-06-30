{pkgs, ...}: {
  # Default unnamed instance → /run/redis/redis.sock + 127.0.0.1:6379
  services.redis.servers."" = {
    enable = true;
    bind = "127.0.0.1";
    port = 6379;

    # No persistence — dev cache, data is disposable
    appendOnly = false;
    save = [];

    settings = {
      maxmemory = "2gb";
      maxmemory-policy = "allkeys-lru";

      tcp-backlog = 511;
      timeout = 0;
      tcp-keepalive = 300;

      io-threads = 4;
      io-threads-do-reads = "yes";

      activerehashing = "yes";
      lazyfree-lazy-eviction = "yes";
      lazyfree-lazy-expire = "yes";
      lazyfree-lazy-server-del = "yes";
    };
  };

  environment.systemPackages = [pkgs.iredis];
}
