{
  pkgs,
  config,
  inputs,
  ...
}: let
  context7-wrapper = pkgs.writeShellScript "context7" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    npx -y @upstash/context7-mcp --api-key $(cat ${config.sops.secrets.context7.path})
  '';
in {
  sops.secrets.context7.sopsFile = "${inputs.nix-secrets}/global/api-keys/context7.yaml";

  programs.code-assistant-profiles.addons.context7 = {
    mcpServers.context7.command = "${context7-wrapper}";

    rules.context7.content.source = ./rule.md;
  };
}
