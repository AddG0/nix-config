#############################################################
#
#  Apache Druid - Real-time Analytics Database
#
###############################################################
{
  pkgs,
  lib,
  config,
  ...
}: let
  druidHost = "localhost";

  # Package's cluster config uses file appenders that fail in NixOS
  log4j = pkgs.writeText "log4j2.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <Configuration status="WARN">
      <Appenders>
        <Console name="Console" target="SYSTEM_OUT">
          <PatternLayout pattern="%d{ISO8601} %p [%t] %c - %m%n"/>
        </Console>
      </Appenders>
      <Loggers>
        <Root level="info">
          <AppenderRef ref="Console"/>
        </Root>
      </Loggers>
    </Configuration>
  '';

  # Required for PostgreSQL Unix socket connections (peer auth)
  junixsocketJars = [
    "${pkgs.junixsocket-common}/share/java/*"
    "${pkgs.junixsocket-native-common}/share/java/*"
  ];
in {
  services.druid = {
    inherit log4j;
    extraClassPaths = junixsocketJars;

    commonConfig = {
      # PostgreSQL via Unix socket for peer authentication
      "druid.metadata.storage.type" = "postgresql";
      "druid.metadata.storage.connector.connectURI" = "jdbc:postgresql://localhost/druid?socketFactory=org.newsclub.net.unix.AFUNIXSocketFactory$FactoryArg&socketFactoryArg=/run/postgresql/.s.PGSQL.5432";
      "druid.metadata.storage.connector.user" = "druid";

      "druid.storage.type" = "local";
      "druid.storage.storageDirectory" = "/var/lib/druid/segments";

      "druid.indexer.logs.type" = "file";
      "druid.indexer.logs.directory" = "/var/lib/druid/indexing-logs";

      "druid.zk.service.host" = "localhost:26181";
      "druid.zk.paths.base" = "/druid";

      "druid.extensions.loadList" = ''["druid-histogram", "druid-datasketches", "druid-lookups-cached-global", "postgresql-metadata-storage", "druid-kafka-indexing-service"]'';
    };

    coordinator = {
      enable = true;
      restartIfChanged = true;
      jvmArgs = "-Xms1g -Xmx1g";
      config = {
        "druid.plaintextPort" = 26081;
        "druid.host" = druidHost;
        "druid.coordinator.startDelay" = "PT30S";
        "druid.coordinator.period" = "PT30S";
      };
    };

    overlord = {
      enable = true;
      restartIfChanged = true;
      jvmArgs = "-Xms1g -Xmx1g";
      config = {
        "druid.plaintextPort" = 26090;
        "druid.host" = druidHost;
        "druid.indexer.queue.startDelay" = "PT5S";
      };
    };

    broker = {
      enable = true;
      restartIfChanged = true;
      jvmArgs = "-Xms6g -Xmx6g -XX:MaxDirectMemorySize=2g";
      config = {
        "druid.plaintextPort" = 26082;
        "druid.host" = druidHost;
        "druid.broker.http.numConnections" = 20;
        "druid.server.http.numThreads" = 50;
        "druid.processing.buffer.sizeBytes" = 500000000;
        "druid.processing.numThreads" = 4;
        "druid.processing.numMergeBuffers" = 2;
        "druid.lookup.snapshotWorkingDir" = "/var/lib/druid/lookup-snapshots";
      };
    };

    historical = {
      enable = true;
      restartIfChanged = true;
      # Direct memory must exceed: bufferSize × (numThreads + numMergeBuffers + 1)
      jvmArgs = "-Xms12g -Xmx12g -XX:MaxDirectMemorySize=7g";
      segmentLocations = [
        {
          path = "/var/lib/druid/segment-cache";
          maxSize = "100g";
          freeSpacePercent = 5.0;
        }
      ];
      config = {
        "druid.plaintextPort" = 26083;
        "druid.host" = druidHost;
        "druid.server.maxSize" = 100000000000;
        "druid.processing.buffer.sizeBytes" = 500000000;
        "druid.processing.numThreads" = 8;
        "druid.processing.numMergeBuffers" = 4;
        "druid.historical.cache.useCache" = "true";
        "druid.historical.cache.populateCache" = "true";
        "druid.lookup.snapshotWorkingDir" = "/var/lib/druid/lookup-snapshots";
      };
    };

    middleManager = {
      enable = true;
      restartIfChanged = true;
      jvmArgs = "-Xms512m -Xmx512m";
      config = {
        "druid.plaintextPort" = 26091;
        "druid.host" = druidHost;
        "druid.worker.capacity" = 8;
        # Peon JVM settings (each ingestion task runs as separate process)
        "druid.indexer.runner.javaOptsArray" = ''["-Xms4g", "-Xmx4g", "-XX:MaxDirectMemorySize=1g"]'';
        "druid.indexer.task.baseTaskDir" = "/var/lib/druid/task";
        "druid.indexer.runner.startPort" = 26100;
        "druid.indexer.runner.endPort" = 26200;
      };
    };

    # Unified entry point - required for console to reach all services via nginx
    router = {
      enable = true;
      restartIfChanged = true;
      jvmArgs = "-Xms512m -Xmx512m";
      config = {
        "druid.plaintextPort" = 26888;
        "druid.host" = druidHost;
        "druid.router.defaultBrokerServiceName" = "druid/broker";
        "druid.router.coordinatorServiceName" = "druid/coordinator";
        "druid.router.managementProxy.enabled" = "true";
      };
    };
  };

  # Required for Druid cluster coordination
  services.zookeeper = {
    enable = true;
    dataDir = "/var/lib/zookeeper";
    extraConf = ''
      clientPort=26181
      admin.serverPort=26180
    '';
  };

  services.postgresql = {
    ensureDatabases = ["druid"];
    ensureUsers = [
      {
        name = "druid";
        ensureDBOwnership = true;
      }
    ];
    # Must match database.nix priority (mkOverride 10)
    authentication = lib.mkOverride 10 ''
      local druid druid peer
    '';
  };

  # Paths from commonConfig aren't auto-created by the module
  systemd.tmpfiles.rules = [
    "d /var/lib/druid/segments 0755 druid druid -"
    "d /var/lib/druid/indexing-logs 0755 druid druid -"
  ];

  # Resolve druid domain locally
  networking.hosts."127.0.0.1" = ["druid.${config.hostSpec.domain}"];

  # External HTTPS access via nginx
  services.nginx.virtualHosts."druid.${config.hostSpec.domain}" = {
    useACMEHost = config.hostSpec.domain;
    forceSSL = true;
    # Route indexer API directly to overlord (router doesn't forward logs)
    locations."/druid/indexer/" = {
      proxyPass = "http://127.0.0.1:26090";
      proxyWebsockets = true;
    };
    locations."/" = {
      proxyPass = "http://127.0.0.1:26888";
      proxyWebsockets = true;
    };
  };
}
