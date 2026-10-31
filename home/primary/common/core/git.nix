{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (config.hostSpec) handle;
  publicGitEmail = config.hostSpec.githubEmail;
  personalSigningKey =
    lib.removeSuffix "\n" (builtins.readFile
      (lib.custom.relativeToHosts "common/users/primary/keys/primary.pub"));
  allowedSigners = pkgs.writeText "git-allowed-signers" ''
    ${publicGitEmail} ${personalSigningKey}
  '';
in {
  programs.git.settings = {
    user = {
      name = handle;
      email = publicGitEmail;
      signingkey = personalSigningKey;
    };

    commit.gpgSign = true;
    tag.gpgSign = true;

    gpg = {
      format = "ssh";
      ssh.allowedSignersFile = toString allowedSigners;
    };
  };
}
