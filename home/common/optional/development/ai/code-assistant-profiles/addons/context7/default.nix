{
  pkgs,
  config,
  ...
}: let
  context7-wrapper = pkgs.writeShellScript "context7" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    npx -y @upstash/context7-mcp --api-key $(cat ${config.sops.secrets.context7.path})
  '';
in {
  mcpServers.context7 = {
    command = "${context7-wrapper}";
  };

  rules.context7.content.source = ./rule.md;
}
