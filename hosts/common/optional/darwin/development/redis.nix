{
  pkgs,
  config,
  ...
}: {
  # Redis with high-performance configuration
  services.redis = {
    enable = true;

    # Bind to localhost for security
    bind = "127.0.0.1";

    # Port configuration
    port = 6379;

    # Disable AOF for maximum performance (data not persisted)
    appendOnly = false;

    # High-performance settings via extraConfig
    extraConfig = ''
      # Memory settings
      maxmemory 16gb
      maxmemory-policy allkeys-lru

      # Persistence settings for performance
      save ""
      stop-writes-on-bgsave-error no
      rdbcompression no
      rdbchecksum no

      # Performance tuning
      tcp-backlog 511
      timeout 0
      tcp-keepalive 300

      # Threading and I/O (Redis 6.0+)
      io-threads 8
      io-threads-do-reads yes

      # Memory optimizations
      activerehashing yes
      hz 50
      dynamic-hz yes

      # Client output buffer limits
      client-output-buffer-limit normal 0 0 0
      client-output-buffer-limit replica 256mb 64mb 60
      client-output-buffer-limit pubsub 32mb 8mb 60

      # Lazy freeing for performance
      lazyfree-lazy-eviction yes
      lazyfree-lazy-expire yes
      lazyfree-lazy-server-del yes
      replica-lazy-flush yes

      # Network settings
      tcp-nodelay yes

      # Logging
      loglevel notice
      syslog-enabled no

      # Slow log
      slowlog-log-slower-than 10000
      slowlog-max-len 128

      # Advanced config
      hash-max-ziplist-entries 512
      hash-max-ziplist-value 64
      list-max-ziplist-size -2
      list-compress-depth 0
      set-max-intset-entries 512
      zset-max-ziplist-entries 128
      zset-max-ziplist-value 64
      hll-sparse-max-bytes 3000
      stream-node-max-bytes 4096
      stream-node-max-entries 100

      # Active defragmentation
      activedefrag yes
      active-defrag-ignore-bytes 100mb
      active-defrag-threshold-lower 10
      active-defrag-threshold-upper 100
      active-defrag-cycle-min 5
      active-defrag-cycle-max 75
      active-defrag-max-scan-fields 1000

      # Threaded I/O
      jemalloc-bg-thread yes
    '';
  };

  environment.systemPackages = with pkgs; [
    redis
  ];
}
