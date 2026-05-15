{
  config,
  nix-secrets,
  ...
}: let
  accessTokensPath = "/etc/nix/private/access-tokens.conf";
in {
  sops.secrets.nix-access-token = {
    sopsFile = "${nix-secrets}/global/api-keys/nix-access-token.yaml";
    key = "github";
    mode = "0400";
    owner = "root";
  };

  sops.templates."nix-access-tokens.conf" = {
    path = accessTokensPath;
    mode = "0400";
    owner = "root";
    content = "access-tokens = github.com=${config.sops.placeholder."nix-access-token"}\n";
  };

  systemd.tmpfiles.rules = [
    "d ${dirOf accessTokensPath} 0700 root root -"
  ];

  nix.git-sync.accessTokensFile = accessTokensPath;
}
