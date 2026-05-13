{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  bucketName = "nix-cache-a530-nix-binary-cache";
  cachePublicKey = "personal-nix-cache:UjZ7D/QNTD8Rgihk5XdxHq2POpKlIZe3SPj8+qScv74=";

  cacheUrl = "s3://${bucketName}?endpoint=https://storage.googleapis.com&profile=personal-nix-cache&want-mass-query=true";

  rootHome =
    if pkgs.stdenv.isDarwin
    then "/var/root"
    else "/root";
  awsCredentialsPath = "${rootHome}/.aws/credentials";

  nixCacheSops = "${inputs.nix-secrets}/global/nix-cache.yaml";
in {
  imports = [
    inputs.queued-build-hook.nixosModules.queued-build-hook
  ];

  sops = {
    secrets = {
      nix_cache_signing_key = {
        sopsFile = nixCacheSops;
        key = "signing_key";
      };
      nix_cache_hmac_access_key = {
        sopsFile = nixCacheSops;
        key = "hmac_access_key";
      };
      nix_cache_hmac_secret_key = {
        sopsFile = nixCacheSops;
        key = "hmac_secret_key";
      };
    };

    templates."nix-cache-aws-credentials" = {
      path = awsCredentialsPath;
      mode = "0400";
      owner = "root";
      content = ''
        [personal-nix-cache]
        aws_access_key_id = ${config.sops.placeholder.nix_cache_hmac_access_key}
        aws_secret_access_key = ${config.sops.placeholder.nix_cache_hmac_secret_key}
      '';
    };
  };

  systemd.tmpfiles.rules = lib.mkIf pkgs.stdenv.isLinux [
    "d ${rootHome}/.aws 0700 root root -"
  ];

  system.activationScripts.nixCacheAwsDir = lib.mkIf pkgs.stdenv.isDarwin {
    text = ''
      mkdir -p ${rootHome}/.aws
      chmod 700 ${rootHome}/.aws
    '';
  };

  nix.settings = {
    substituters = [cacheUrl];
    trusted-public-keys = [cachePublicKey];
  };

  services.queued-build-hook = {
    enable = true;
    concurrency = 1; # one nix copy at a time so xz compression doesn't peg every core
    retries = 3;
    retryIntervalSecs = 30;
    # Yield to anything else competing for CPU/disk. Total CPU is unchanged
    # but interactive work and builds win.
    nice = 19;
    cpuSchedulingPolicy = "idle";
    ioSchedulingClass = "idle";

    # Daemon subscribes to NetworkManager's Metered D-Bus property. Pulled
    # jobs park (queue keeps growing) until the connection is unmetered;
    # nothing dropped. No busctl polling, no dispatcher script.
    pauseOnMetered = config.networking.networkmanager.enable;

    # Runs in the queue daemon (DynamicUser). Sign + upload — both keys arrive
    # via systemd LoadCredential so DynamicUser doesn't need filesystem access
    # to /run/secrets.
    workerScript = ''
      export AWS_SHARED_CREDENTIALS_FILE="$CREDENTIALS_DIRECTORY/aws-credentials"
      ${pkgs.nix}/bin/nix store sign \
        --key-file "$CREDENTIALS_DIRECTORY/signing-key" $OUT_PATHS
      exec ${pkgs.nix}/bin/nix copy --to "${cacheUrl}" $OUT_PATHS
    '';

    credentials = {
      # Lowercase names so the upstream module's UPPER_SNAKE auto-export skips
      # them — both are read-as-file inside workerScript, not env vars.
      aws-credentials = awsCredentialsPath;
      signing-key = config.sops.secrets.nix_cache_signing_key.path;
    };
  };
}
