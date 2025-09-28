{
  config,
  lib,
  nix-secrets,
  ...
}: {
  sops.secrets = {
    ssh_id_ed25519_server = {
      format = "binary";
      sopsFile = "${nix-secrets}/secrets/ssh/id_ed25519_server.enc";
      path = "${config.home.homeDirectory}/.ssh/id_ed25519_server";
    };
  };
}
