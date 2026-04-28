{
  pkgs,
  lib,
  ...
}: {
  programs.code-assistant-profiles.addons.grafana = {
    mcpServers.mcp-grafana.command = "${pkgs.mcp-grafana}/bin/mcp-grafana";

    agents."grafana-dashboard-builder".prompt.source = ./agents/grafana-dashboard-builder.md;

    skills."dashboard-review" = lib.custom.ai.fromClaudeSkillDir {
      inherit pkgs;
      source = ./skills/dashboard-review;
    };

    rules."grafana-dashboards".content.source = ./rules/dashboards.md;
  };
}
