{
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  # sqry publishes Linux binaries only; elsewhere the addon stays defined but empty so profiles can still include it.
  available = lib.meta.availableOn pkgs.stdenv.hostPlatform customPkgs.sqry;
in {
  home.packages = lib.optional available customPkgs.sqry;

  # sqry writes its graph into the working copy on first query.
  programs.git.ignores = lib.optional available ".sqry/";

  programs.code-assistant-profiles.addons.sqry = lib.optionalAttrs available {
    # No flags: falls back to in-process standalone, which exposes all 37 tools (daemon mode, 16).
    mcpServers.sqry = {
      command = "${customPkgs.sqry}/bin/sqry-mcp";
      # Path redaction only adds correlation work — Claude already reads the files.
      env.SQRY_REDACTION_PRESET = "none";
    };

    rules.sqry.content.source = ./rules/sqry.md;
  };
}
