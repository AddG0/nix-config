{ config, pkgs, lib, ... }:

{
  # Enable monitoring services
  services.prometheus = {
    enable = false;

    port = 9090;
    listenAddress = "127.0.0.1";

    # Configure global settings
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
      external_labels = {
        monitor = "ghost-darwin";
        environment = "development";
      };
    };

    # Configure scrape configs
    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [{
          targets = [ "127.0.0.1:9090" ];
          labels = {
            alias = "prometheus";
          };
        }];
      }

      {
        job_name = "grafana";
        static_configs = [{
          targets = [ "127.0.0.1:3080" ];
          labels = {
            alias = "grafana";
          };
        }];
      }

      {
        job_name = "loki";
        static_configs = [{
          targets = [ "127.0.0.1:3100" ];
          labels = {
            alias = "loki";
          };
        }];
      }
      {
        job_name = "shipperws";
        static_configs = [{
          targets = [ "localhost:8080" ];
          labels = {
            alias = "shipperws";
          };
        }];
        metrics_path = "/shipperhq-ws/actuator/prometheus";
        scrape_interval = "500ms";
      }
      {
        job_name = "shipperws-jo";
        static_configs = [{
        targets = [ "192.168.68.119:8080" ];
          labels = {
            alias = "shipperws-jo";
          };
        }];
        metrics_path = "/shipperhq-ws/actuator/prometheus";
        scrape_interval = "500ms";
      }
      # Node exporter for system metrics
      # {
      #   job_name = "node";
      #   static_configs = [{
      #     targets = [ "127.0.0.1:9100" ];
      #     labels = {
      #       alias = "ghost-system";
      #     };
      #   }];
      # }
    ];

    # Configure alerting rules
    rules = [
      ''
        groups:
        - name: system_alerts
          interval: 30s
          rules:
          - alert: HighCPUUsage
            expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High CPU usage detected"
              description: "CPU usage is above 80% (current value: {{ $value }}%)"

          - alert: HighMemoryUsage
            expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High memory usage detected"
              description: "Memory usage is above 90% (current value: {{ $value }}%)"

          - alert: DiskSpaceLow
            expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|squashfs|vfat"} / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs|squashfs|vfat"}) * 100 < 10
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Low disk space"
              description: "Disk space is below 10% free (current value: {{ $value }}%)"
      ''
    ];

    # Set retention time for metrics
    retentionTime = "30d";
  };

  services.grafana = {
    enable = false;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3080;
        domain = "localhost";
        root_url = "http://localhost:3080/";
        serve_from_sub_path = false;
      };

      database = {
        type = "sqlite3";
        path = "/var/lib/grafana/data/grafana.db";
      };

      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
      };

      security = {
        admin_user = "admin";
        disable_gravatar = true;
        cookie_secure = false;
        cookie_samesite = "lax";
      };

      users = {
        allow_sign_up = false;
        allow_org_create = false;
        auto_assign_org = true;
        auto_assign_org_role = "Editor";
        viewers_can_edit = true;
      };

      auth = {
        disable_login_form = false;
      };

      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Editor";
      };

      log = {
        mode = "console file";
        level = "info";
      };
    };

    # Provision datasources
    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;

        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
            isDefault = true;
            editable = false;
            jsonData = {
              timeInterval = "15s";
            };
          }

          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://127.0.0.1:3100";
            editable = false;
          }
        ];

        deleteDatasources = [];
      };

      # Provision dashboards
      dashboards.settings = {
        apiVersion = 1;

        providers = [
          {
            name = "Default";
            type = "file";
            options.path = "/var/lib/grafana/dashboards";
          }
        ];
      };
    };

    # Install useful plugins
    declarativePlugins = with pkgs.grafanaPlugins; [
      grafana-piechart-panel
      grafana-clock-panel
      grafana-worldmap-panel
      volkovlabs-variable-panel
    ] ++ (with pkgs.grafana-plugins; [
      marcusolsson-gantt-panel
    ]);
  };

  services.loki = {
    enable = false;

    # Skip validation to avoid issues with config format
    extraFlags = [ "-config.expand-env=true" ];

    configuration = {
      auth_enabled = false;

      server = {
        http_listen_address = "0.0.0.0";
        http_listen_port = 3100;
        grpc_listen_port = 9096;

        # High throughput server settings
        http_server_read_timeout = "5m";
        http_server_write_timeout = "5m";
        grpc_server_max_recv_msg_size = 104857600; # 100MB
        grpc_server_max_send_msg_size = 104857600; # 100MB
        grpc_server_max_concurrent_streams = 1000;
        log_level = "warn"; # Reduce log noise under heavy load
      };

      common = {
        path_prefix = "/var/lib/loki";
        storage = {
          filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
        };
        replication_factor = 1;
        ring = {
          instance_addr = "127.0.0.1";
          kvstore = {
            store = "inmemory";
          };
        };
      };

      schema_config = {
        configs = [
          {
            from = "2020-10-24";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
          cache_ttl = "24h";
        };
        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
          final_sleep = "0s";
        };

        # High throughput ingestion settings
        chunk_idle_period = "10s";  # Flush chunks faster
        chunk_retain_period = "5s"; # Reduce retention for faster processing
        chunk_block_size = 2097152; # 2MB blocks for high throughput
        chunk_target_size = 16777216; # 16MB target size
        max_chunk_age = "2m"; # Age out chunks faster

        # WAL settings for high throughput
        wal = {
          dir = "/var/lib/loki/wal";
          replay_memory_ceiling = "1GB"; # Increase WAL replay memory
        };

        # Concurrent processing
        concurrent_flushes = 16;
        flush_check_period = "10s";

        # Memory settings for high load
        max_returned_stream_errors = 100;
      };

      limits_config = {
        retention_period = "744h";
        reject_old_samples = false;
        allow_structured_metadata = false;

        # Massive line size limits
        max_line_size = "10MB";
        max_line_size_truncate = false;

        # Ultra high ingestion rates for millions per second
        ingestion_rate_mb = 10000;
        ingestion_burst_size_mb = 50000;

        # Massive stream limits
        max_streams_per_user = 1000000;
        max_global_streams_per_user = 5000000;

        # High query limits
        max_query_length = "12000h";
        max_query_parallelism = 32;
        max_query_series = 100000;

        # Large chunk limits for high throughput
        max_chunks_per_query = 2000000;
        max_entries_limit_per_query = 10000000;

        # Per-tenant rate limits (set very high)
        per_stream_rate_limit = "100MB";
        per_stream_rate_limit_burst = "500MB";

        # Cardinality limits
        max_label_name_length = 1024;
        max_label_value_length = 4096;
        max_label_names_per_series = 30;
      };


      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/var/lib/loki/boltdb-shipper-compactor";
      };
    };
  };

  # Create Grafana dashboard
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    # Create directories for dashboard provisioning
    mkdir -p /var/lib/grafana/dashboards
    chown -R ${config.services.grafana.user}:${config.services.grafana.group} /var/lib/grafana/dashboards

    # Create a basic system dashboard
    cat > /var/lib/grafana/dashboards/system.json << 'EOF'
{
  "id": null,
  "uid": "system-overview",
  "title": "System Overview",
    "tags": ["system"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 0,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "type": "graph",
        "title": "CPU Usage",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %",
            "refId": "A"
          }
        ],
        "yaxes": [
          {
            "format": "percent",
            "min": 0,
            "max": 100
          },
          {
            "format": "short"
          }
        ]
      },
      {
        "id": 2,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "type": "graph",
        "title": "Memory Usage",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "Memory Usage %",
            "refId": "A"
          }
        ],
        "yaxes": [
          {
            "format": "percent",
            "min": 0,
            "max": 100
          },
          {
            "format": "short"
          }
        ]
      },
      {
        "id": 3,
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
        "type": "graph",
        "title": "Disk Usage",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "100 - ((node_filesystem_avail_bytes{fstype!~\"tmpfs|fuse.lxcfs|squashfs|vfat\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|fuse.lxcfs|squashfs|vfat\"}) * 100)",
            "legendFormat": "{{mountpoint}} Usage %",
            "refId": "A"
          }
        ],
        "yaxes": [
          {
            "format": "percent",
            "min": 0,
            "max": 100
          },
          {
            "format": "short"
          }
        ]
      }
    ]
}
EOF
    chown ${config.services.grafana.user}:${config.services.grafana.group} /var/lib/grafana/dashboards/system.json
  '';

  # Add helpful aliases for monitoring
  environment.shellAliases = {
    # Prometheus
    prom-status = "prometheus-status";
    prom-restart = "prometheus-restart";
    prom-logs = "prometheus-logs";

    # Grafana
    graf-status = "grafana-status";
    graf-restart = "grafana-restart";
    graf-logs = "grafana-logs";

    # Loki
    loki-status = "loki-status";
    loki-restart = "loki-restart";
    loki-logs = "loki-logs";

    # Combined
    monitoring-status = "echo '=== Prometheus ===' && prometheus-status && echo '\n=== Grafana ===' && grafana-status && echo '\n=== Loki ===' && loki-status";
    monitoring-restart = "prometheus-restart && grafana-restart && loki-restart";
    monitoring-logs = "prometheus-logs && echo '\n---\n' && grafana-logs && echo '\n---\n' && loki-logs";
  };

  # Open ports in firewall (if using one)
  # networking.firewall.allowedTCPPorts = [ 3080 3100 9090 ];
}