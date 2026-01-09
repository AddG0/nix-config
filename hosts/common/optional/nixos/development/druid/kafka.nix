#############################################################
#
#  Apache Kafka - Distributed Event Streaming (KRaft mode)
#
###############################################################
{pkgs, ...}: {
  services.apache-kafka = {
    enable = true;
    clusterId = "MkU3OEVBNTcwNTJENDM2Qk";
    formatLogDirs = true;
    # OpenTelemetry Java agent for metrics - pushes directly via OTLP
    jvmOptions = [
      "-javaagent:${pkgs.opentelemetry-javaagent}/share/java/opentelemetry-javaagent.jar"
      "-Dotel.jmx.target.system=kafka-broker"
      "-Dotel.service.name=kafka"
      "-Dotel.metrics.exporter=otlp"
      "-Dotel.traces.exporter=none"
      "-Dotel.logs.exporter=none"
    ];
    settings = {
      # Combined broker+controller mode for single-node setup
      "process.roles" = ["broker" "controller"];
      "node.id" = 1;
      # Both needed: voters for format command, bootstrap.servers for runtime
      "controller.quorum.voters" = "1@127.0.0.1:9093";
      "controller.quorum.bootstrap.servers" = "127.0.0.1:9093";
      "controller.listener.names" = ["CONTROLLER"];

      "listeners" = ["PLAINTEXT://127.0.0.1:9092" "CONTROLLER://127.0.0.1:9093"];
      "advertised.listeners" = ["PLAINTEXT://127.0.0.1:9092"];
      "listener.security.protocol.map" = "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT";
      "inter.broker.listener.name" = "PLAINTEXT";

      "num.network.threads" = 4;
      "num.io.threads" = 8;

      "log.dirs" = ["/var/lib/kafka/logs"];
      "num.partitions" = 8;
      # Single node requires replication factor of 1
      "default.replication.factor" = 1;
      "offsets.topic.replication.factor" = 1;
      "transaction.state.log.replication.factor" = 1;
      "transaction.state.log.min.isr" = 1;
      "log.retention.hours" = 168;
      "log.segment.bytes" = 1073741824;
      "log.retention.check.interval.ms" = 300000;

      "socket.send.buffer.bytes" = 1048576;
      "socket.receive.buffer.bytes" = 1048576;
      "socket.request.max.bytes" = 104857600;
      "message.max.bytes" = 10485760;

      # Async flush for throughput (data loss risk on crash)
      "log.flush.interval.messages" = 10000;
      "log.flush.interval.ms" = 1000;
    };
  };
}
