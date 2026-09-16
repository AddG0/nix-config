# A gradle.properties carrying a secret cannot come from the store, so sops renders it instead.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.gradle;
  hasSecrets = cfg.secretSettings != {};
  format = pkgs.formats.javaProperties {};

  # sops.placeholder is gated on the template set, so hasSecrets must not read one — values name secrets instead.
  secretPlaceholders = lib.mapAttrs (_: secret: config.sops.placeholder.${secret}) cfg.secretSettings;
in {
  options.programs.gradle.secretSettings = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    example = lib.literalExpression ''{ shqGitlabToken = "gitlab_token"; }'';
    description = ''
      Entries for `settings` whose value names the `sops.secrets` entry to take
      the value from. One of these renders the whole file at activation and
      points `settings` at the result — Gradle reads a single user-level
      properties file, so the secret and public entries cannot be split.
    '';
  };

  config = lib.mkIf hasSecrets {
    sops.templates."gradle.properties" = {
      file = format.generate "gradle.properties" (cfg.settings // secretPlaceholders);
      mode = "0600";
    };

    home.file."${cfg.home}/gradle.properties".source =
      lib.mkForce (config.lib.file.mkOutOfStoreSymlink config.sops.templates."gradle.properties".path);
  };
}
