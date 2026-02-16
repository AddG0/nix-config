# xrdp - Remote Desktop Protocol server
# Spawns an independent X11 Plasma session per connection (separate from local Wayland session).
# Connect via Microsoft Remote Desktop on Mac. No local login required.
#
# Session management:
#   loginctl list-sessions          # list all sessions (remote = no seat)
#   loginctl terminate-session <ID> # kill a specific session
#
# Each RDP connection creates a new session. Disconnect cleanly or
# terminate stale sessions to avoid duplicates.
#
# Troubleshooting:
#   Stuck on "Configuring remote PC" — disable Clipboard sharing in the
#   Microsoft Remote Desktop connection settings (Devices & Audio tab).
_: {
  services.xrdp = {
    enable = true;
    defaultWindowManager = "startplasma-x11";
    openFirewall = true;
  };
}
