{
  cfg,
  lib,
  ...
}: let
  toPfPorts = ports:
    if ports == []
    then ""
    else "{ " + lib.concatStringsSep ", " (map toString ports) + " }";

  tcpPorts = toPfPorts cfg.allowedTCPPorts;
  udpPorts = toPfPorts cfg.allowedUDPPorts;

  portRules = ''
    ${
      if tcpPorts != ""
      then "pass in proto tcp to port ${tcpPorts} keep state"
      else ""
    }
    ${
      if udpPorts != ""
      then "pass in proto udp to port ${udpPorts} keep state"
      else ""
    }
  '';

  icmp =
    if cfg.allowICMP
    then "pass inet proto icmp all"
    else "";
in ''
  # Default macOS PF anchors
  scrub-anchor "com.apple/*"
  nat-anchor "com.apple/*"
  rdr-anchor "com.apple/*"
  dummynet-anchor "com.apple/*"
  anchor "com.apple/*"
  load anchor "com.apple" from "/etc/pf.anchors/com.apple"

  # Skip loopback interface
  set skip on lo0

  # Block all incoming traffic by default
  block in all

  # Allow all outbound traffic
  pass out all keep state

  # Allow specific ports
  ${portRules}

  # Allow ICMP if configured
  ${icmp}
''
