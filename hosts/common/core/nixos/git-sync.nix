{lib, ...}: {
  nix.git-sync.allowedSigners = [
    (lib.removeSuffix "\n" (builtins.readFile (lib.custom.relativeToHosts "common/users/primary/keys/primary.pub")))
  ];

  # git-sync's accept-new only trusts unknown hosts, so pinning github.com here refuses a spoofed key.
  programs.ssh.knownHosts."github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
}
