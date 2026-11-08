{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: let
  # Keyless context7 still works, at lower rate limits.
  withApiKey = !config.hostSpec.disableSops;
  context7-wrapper = pkgs.writeShellScript "context7" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    npx -y @upstash/context7-mcp ${lib.optionalString withApiKey "--api-key $(cat ${config.sops.secrets.context7.path})"}
  '';
in {
  sops.secrets = lib.mkIf withApiKey {
    context7.sopsFile = "${inputs.nix-secrets}/global/api-keys/context7.yaml";
  };

  programs.code-assistant-profiles.addons.context7 = {
    mcpServers.context7.command = "${context7-wrapper}";

    rules.context7.content.source = ./rules/context7.md;
  };
}
