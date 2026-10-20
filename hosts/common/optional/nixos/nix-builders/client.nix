# Offloads builds to the fleet builders, skipping any whose latency is too high.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  inherit (import ../../_nix-builders.nix) builders;
  inherit (config.hostSpec.networking) hostsAddr;
  cfg = config.nix.remoteBuilder;

  host = config.hostSpec.hostName;
  remoteBuilders = lib.filterAttrs (name: _: name != host) builders;
  activeMachines = "/run/nix-builders/machines";

  probe = pkgs.writeShellApplication {
    name = "nix-builder-probe";
    runtimeInputs = with pkgs; [coreutils netcat];
    text = ''
      out=${activeMachines}
      port=${toString config.hostSpec.networking.ports.tcp.ssh}

      # Best of three TCP connects to sshd, in microseconds; fails if all three time out.
      rtt_us() {
        local best="" s e us err=""
        for _ in 1 2 3; do
          s=$EPOCHREALTIME
          if err=$(nc -z -w 1 "$1" "$port" 2>&1); then
            e=$EPOCHREALTIME
            us=$(( ''${e//[.,]/} - ''${s//[.,]/} ))
            if [[ -z $best ]] || (( us < best )); then best=$us; fi
          fi
        done
        if [[ -z $best ]]; then
          echo "$1:$port: ''${err:-no connection within 1s}" >&2
          return 1
        fi
        echo "$best"
      }

      tmp=$(mktemp "$out.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      summary="builders:"
      while read -r uri rest; do
        [[ -z $uri || $uri == \#* ]] && continue
        addr=''${uri#*@}
        if ! us=$(rtt_us "$addr"); then
          summary+=" $addr unreachable"
        elif (( us > ${toString cfg.maxLatencyMs} * 1000 )); then
          summary+=" $addr $((us / 1000))ms dropped"
        else
          summary+=" $addr $((us / 1000))ms"
          printf '%s %s\n' "$uri" "$rest" >> "$tmp"
        fi
      done < /etc/nix/machines

      chmod 644 "$tmp"
      if [[ -f $out ]] && cmp -s "$tmp" "$out"; then
        rm "$tmp"
      else
        echo "$summary"
        mv -f "$tmp" "$out"
      fi
    '';
  };
in {
  options.nix.remoteBuilder = {
    maxLatencyMs = lib.mkOption {
      # nc gives up after 1s, so a higher cutoff could never apply.
      type = lib.types.ints.between 1 1000;
      default = 50;
      description = "Builders whose TCP connect time to sshd exceeds this are left out.";
    };
  };

  config = {
    assertions = [
      {
        assertion = !config.hostSpec.disableSops;
        message = "nix-builders: ${host} imports nix-builders.client, which needs sops (builder key) and hostsAddr; both are absent with hostSpec.disableSops";
      }
    ];

    sops.secrets.nix-builder-key = {
      sopsFile = "${inputs.nix-secrets}/global/nix-builder-key.enc";
      format = "binary";
      mode = "0400";
    };

    # Both name and IP, since ssh may resolve the builder to either.
    programs.ssh.knownHosts =
      lib.mapAttrs (name: builder: {
        hostNames = [name hostsAddr.${name}.ipv4];
        publicKey = builder.hostKey;
      })
      remoteBuilders;

    nix = {
      distributedBuilds = true;
      buildMachines =
        lib.mapAttrsToList (name: builder: {
          hostName = hostsAddr.${name}.ipv4;
          inherit (builder) system maxJobs speedFactor supportedFeatures;
          protocol = "ssh-ng";
          sshUser = "builder";
          sshKey = config.sops.secrets.nix-builder-key.path;
        })
        remoteBuilders;

      settings = {
        # Latency-filtered by the probe; `--builders @/etc/nix/machines` uses every builder.
        builders = "@${activeMachines}";
        # Use substitutes on builders to avoid uploading everything
        builders-use-substitutes = true;
      };
    };

    systemd.services.nix-builder-probe = {
      description = "Offer only low-latency remote Nix builders";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe probe;
        RuntimeDirectory = "nix-builders";
        RuntimeDirectoryPreserve = true;
      };
    };

    systemd.timers.nix-builder-probe = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnActiveSec = "10s";
        OnUnitActiveSec = "30s";
        AccuracySec = "1s";
      };
    };
  };
}
