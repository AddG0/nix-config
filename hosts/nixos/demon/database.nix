{ config, lib, pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "chatbot" ];
    ensureUsers = [
      {
        name = "addg";
        ensureClauses.superuser = true;
      }
      {
        name = "devuser";
        ensureDBOwnership = false;
      }
    ];
    initialScript = pkgs.writeText "backend-initScript" ''
      ALTER USER devuser PASSWORD 'devpass';
    '';
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             postgres                                peer
      local   all             addg                                    peer
      host    all             all             127.0.0.1/32            scram-sha-256
      host    all             all             ::1/128                 scram-sha-256
    '';
    settings = {
      shared_buffers = "256MB";
      effective_cache_size = "1GB";
      maintenance_work_mem = "64MB";
      work_mem = "4MB";
    };
  };

  # Open PostgreSQL port in firewall (optional, only if you need external access)
  # networking.firewall.allowedTCPPorts = [ 5432 ];

  # Backup configuration (optional)
  # services.postgresqlBackup = {
  #   enable = true;
  #   databases = [ "mydatabase" ];
  #   location = "/var/backup/postgresql";
  #   startAt = "*-*-* 03:00:00";
  # };
}
