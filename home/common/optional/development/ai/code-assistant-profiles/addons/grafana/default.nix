# mcp-grafana reads credentials from environment variables (no flags).
# Required:
#   GRAFANA_URL                    e.g. http://localhost:3000 or https://<org>.grafana.net
#   GRAFANA_SERVICE_ACCOUNT_TOKEN  recommended auth method
#   - or GRAFANA_USERNAME + GRAFANA_PASSWORD (basic auth)
#   - or GRAFANA_API_KEY (deprecated)
# Optional:
#   GRAFANA_ORG_ID         numeric org ID for non-default orgs
#   GRAFANA_EXTRA_HEADERS  JSON object of extra headers, e.g. {"X-Tenant-ID":"123"}
#   GRAFANA_FORWARD_HEADERS  comma-separated header allowlist (SSE/streamable-http only)
# Upstream: https://github.com/grafana/mcp-grafana
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
