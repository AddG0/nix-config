{optional, ...}: {
  gaming.nixos = with optional.hosts.nixos.gaming; [controllers decky gamemode gamescope gamescope-session kernel steam];
}
