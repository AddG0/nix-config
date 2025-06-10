{
  config,
  lib,
  isDarwin,
  ...
}:
with lib; let
  cfg = config.security.firewall;
  pfConf = import ./pf-generator.nix {inherit cfg lib;};
in {
  options.security.firewall = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the cross-platform firewall.";
    };

    allowedTCPPorts = mkOption {
      type = types.listOf types.port;
      default = [];
      description = "Allowed TCP ports.";
    };

    allowedUDPPorts = mkOption {
      type = types.listOf types.port;
      default = [];
      description = "Allowed UDP ports.";
    };

    allowICMP = mkOption {
      type = types.bool;
      default = true;
      description = "Allow ICMP (e.g., ping).";
    };

    allowFromIPs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of source IPs allowed for inbound rules.";
    };

    denyOutboundIPs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of IPs to block for outbound connections.";
    };
  };

  config = mkIf cfg.enable (
    mkMerge (
      lib.optional isDarwin {
        environment.etc."pf.conf".text = pfConf;

        launchd.daemons.pf = {
          serviceConfig = {
            Label = "com.nix.pf";
            ProgramArguments = ["/sbin/pfctl" "-f" "/etc/pf.conf" "-e"];
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 30;
            StandardErrorPath = "/var/log/pf.log";
            StandardOutPath = "/var/log/pf.log";
            ProcessType = "Interactive";
          };
        };

        system.activationScripts.pfctlFirewall = lib.stringAfter ["etc"] ''
          echo "→ Configuring macOS firewall..."

          # Handle backup and restoration of original pf.conf
          if [ -f /etc/pf.conf.before-nix-darwin ]; then
            if [ "${toString cfg.enable}" = "false" ]; then
              echo "Restoring original pf.conf..."
              cp /etc/pf.conf.before-nix-darwin /etc/pf.conf
              rm /etc/pf.conf.before-nix-darwin
              /sbin/pfctl -f /etc/pf.conf -e || true
            fi
          elif [ -f /etc/pf.conf ]; then
            echo "Backing up original pf.conf..."
            cp /etc/pf.conf /etc/pf.conf.before-nix-darwin
          fi

          /sbin/pfctl -d 2>/dev/null || true

          if /sbin/pfctl -f /etc/pf.conf -e; then
            echo "✓ Firewall rules loaded successfully"
            echo "Current rules:"
            /sbin/pfctl -s rules
          else
            echo "⚠ Failed to load firewall rules"
            echo "Current status:"
            /sbin/pfctl -s info
            exit 1
          fi
        '';
      }
      ++ lib.optional (!isDarwin) {
        networking.firewall = {
          enable = true;
          allowPing = cfg.allowICMP;
          allowedTCPPorts = cfg.allowedTCPPorts;
          allowedUDPPorts = cfg.allowedUDPPorts;
          extraCommands = lib.concatStringsSep "\n" (
            map (ip: "iptables -A OUTPUT -d ${ip} -j DROP") cfg.denyOutboundIPs
          );
        };
      }
    )
  );
}
