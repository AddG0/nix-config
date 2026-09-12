{
  config,
  nix-secrets,
  ...
}: {
  # git-sync runs as a systemd service with no ssh agent, so it needs a key on
  # disk. Encrypted to the git-sync hosts only — see nix-secrets/.sops.yaml.
  sops.secrets.nix-secrets-deploy-key = {
    sopsFile = "${nix-secrets}/global/nix-secrets-deploy-key.enc";
    format = "binary";
    mode = "0400";
    owner = "root";
  };

  nix.git-sync.sshKey = config.sops.secrets.nix-secrets-deploy-key.path;
}
