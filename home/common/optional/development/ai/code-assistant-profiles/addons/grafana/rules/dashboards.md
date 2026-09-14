Grafana, over the MCP server:

- Read with `get_dashboard_summary` or `get_dashboard_property` and a JSONPath. `get_dashboard_by_uid` returns the whole JSON and blows out context on any real dashboard.
- Modify with patch operations (`uid` + `operations`). Full JSON is for new dashboards only.
- Verify after writing — `get_dashboard_summary` for structure, `query_prometheus` for whether the queries return anything.

Dashboard conventions, when building or editing panels:

- Pick a framework first: RED for request-driven services, USE for infrastructure, Four Golden Signals for SRE.
- One dashboard answers one question. Under ~20 panels; split into linked dashboards past that.
- Summary stats top, trends middle, detail and logs bottom; general to specific.
- Color encodes state — green healthy, amber warning, red critical — never decoration. Threshold only on actionable conditions.
- `$__rate_interval` in `rate()`/`increase()`, never a hardcoded interval. `sum by (label)`, never `sum without`.
- Template variables instead of one dashboard per instance; chain them hierarchically. Never repeat panels over a high-cardinality variable — each repeat is its own query.
- Panel descriptions say what the panel shows and what "bad" looks like.

The `grafana-dashboard-builder` agent carries the rest: panel-type selection, PromQL and
LogQL patterns, JSON defaults, OTel metric naming, and cross-signal linking.
