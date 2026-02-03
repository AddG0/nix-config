# Grafana addon - Grafana instance access via MCP
# Requires: GRAFANA_URL and GRAFANA_SERVICE_ACCOUNT_TOKEN environment variables
{pkgs, ...}: {
  mcpServers.mcp-grafana.command = "${pkgs.mcp-grafana}/bin/mcp-grafana";

  settings.permissions.allow = [
    # Search
    "mcp__mcp-grafana__search_dashboards"
    # Dashboard
    "mcp__mcp-grafana__get_dashboard_by_uid"
    "mcp__mcp-grafana__get_dashboard_summary"
    "mcp__mcp-grafana__get_dashboard_property"
    "mcp__mcp-grafana__get_dashboard_panel_queries"
    # Datasources
    "mcp__mcp-grafana__list_datasources"
    "mcp__mcp-grafana__get_datasource_by_uid"
    "mcp__mcp-grafana__get_datasource_by_name"
    # Prometheus
    "mcp__mcp-grafana__query_prometheus"
    "mcp__mcp-grafana__list_prometheus_metric_metadata"
    "mcp__mcp-grafana__list_prometheus_metric_names"
    "mcp__mcp-grafana__list_prometheus_label_names"
    "mcp__mcp-grafana__list_prometheus_label_values"
    # Loki
    "mcp__mcp-grafana__query_loki_logs"
    "mcp__mcp-grafana__list_loki_label_names"
    "mcp__mcp-grafana__list_loki_label_values"
    "mcp__mcp-grafana__query_loki_stats"
    # Alerting
    "mcp__mcp-grafana__list_alert_rules"
    "mcp__mcp-grafana__get_alert_rule_by_uid"
    "mcp__mcp-grafana__list_contact_points"
    # Incident
    "mcp__mcp-grafana__list_incidents"
    "mcp__mcp-grafana__get_incident"
    # OnCall
    "mcp__mcp-grafana__list_oncall_schedules"
    "mcp__mcp-grafana__get_oncall_shift"
    "mcp__mcp-grafana__get_current_oncall_users"
    "mcp__mcp-grafana__list_oncall_teams"
    "mcp__mcp-grafana__list_oncall_users"
    "mcp__mcp-grafana__list_alert_groups"
    "mcp__mcp-grafana__get_alert_group"
    # Sift
    "mcp__mcp-grafana__get_sift_investigation"
    "mcp__mcp-grafana__get_sift_analysis"
    "mcp__mcp-grafana__list_sift_investigations"
    # Pyroscope
    "mcp__mcp-grafana__list_pyroscope_label_names"
    "mcp__mcp-grafana__list_pyroscope_label_values"
    "mcp__mcp-grafana__list_pyroscope_profile_types"
    "mcp__mcp-grafana__fetch_pyroscope_profile"
    # Asserts
    "mcp__mcp-grafana__get_assertions"
    # Navigation
    "mcp__mcp-grafana__generate_deeplink"
    # Annotations
    "mcp__mcp-grafana__get_annotations"
    "mcp__mcp-grafana__get_annotation_tags"
  ];
}
