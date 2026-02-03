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
  mcpServers.context7.command = "${context7-wrapper}";

  settings.permissions.allow = [
    # Allow all Context7 MCP tools by default
    "mcp__context7__resolve-library-id"
    "mcp__context7__query-docs"
  ];

  memory.text = builtins.readFile ./memory.md;
}
