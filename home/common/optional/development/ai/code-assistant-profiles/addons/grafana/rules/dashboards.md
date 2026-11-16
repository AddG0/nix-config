Grafana, over the MCP server:

- Read with `get_dashboard_summary` or `get_dashboard_property` and a JSONPath. `get_dashboard_by_uid` returns the whole JSON and blows out context on any real dashboard.
- Modify with patch operations (`uid` + `operations`). Full JSON is for new dashboards only.
- Verify after writing — `get_dashboard_summary` for structure, `query_prometheus` for whether the queries return anything.

Build or redesign dashboards through the `grafana-dashboard-builder` agent; it holds the
conventions: framework choice, layout, thresholds, PromQL and LogQL patterns, and JSON defaults.
