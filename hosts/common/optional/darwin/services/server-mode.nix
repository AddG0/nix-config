# Headless server mode: never sleep (including lid closed), auto-restart after
# power loss/freeze, SSH enabled. Pair with services/tailscale.nix for remote access.
_: {
  services.openssh.enable = true;

  power = {
    restartAfterFreeze = true; # restartAfterPowerFailure unsupported on laptops
    sleep = {
      computer = "never";
      display = "never";
      harddisk = "never";
    };
  };

  # Keep the machine awake with the lid shut (clamshell); not exposed by nix-darwin.
  # womp = wake on magic packet (WOL); AC-only on laptops, wired Ethernet only.
  system.activationScripts.serverMode.text = ''
    pmset -a disablesleep 1 powernap 0
    pmset -c womp 1
  '';
}
