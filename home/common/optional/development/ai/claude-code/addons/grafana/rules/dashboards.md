Grafana dashboard conventions:

Layout:
- Z-pattern: summary stats (stat/gauge) top-left, trends middle, detail/tables bottom
- Limit to ~15-20 panels per dashboard; split into linked dashboards if more needed
- Use collapsible rows with descriptive titles to group related panels
- Size panels proportionally to importance
- Each dashboard answers one clear question, not "everything about X"
- Order panels general-to-specific, following data flow or investigation order

Framework:
- Choose RED (Rate, Errors, Duration), USE (Utilization, Saturation, Errors), or Four Golden Signals before building
- RED for request-driven services, USE for infrastructure, Golden Signals for SRE

Color and thresholds:
- Green = healthy, amber = warning, red = critical — never decorative color
- Apply thresholds to stat/gauge panels for traffic-light readability
- Use background color mode on stat panels for wall-screen visibility
- Only threshold on actionable conditions to avoid alert fatigue

Variables and filtering:
- Use template variables to avoid dashboard sprawl (one dashboard per concept, not per instance)
- Chain variables hierarchically (cluster -> namespace -> pod)
- Label variables for readability (e.g., label: "User" for var name user_email)
- Never repeat panels on high-cardinality variables — each repeat fires a separate query

Query patterns:
- Always use `$__rate_interval` in rate()/increase(), not hardcoded intervals
- Prefer `sum by (label)` over `sum without` for explicit grouping
- Use recording rules for expensive queries shared across dashboards
- Set min interval matching the scrape interval
- Use Grafana transformations for client-side calculations instead of extra queries

Documentation:
- Add a text panel at the top with dashboard purpose and data source info
- Use panel descriptions to explain what each panel shows and what "bad" looks like
- Enable shared crosshair (`graphTooltip: 1`) for cross-panel time correlation
- Add deployment annotations where relevant

Performance:
- Match refresh rate to data cadence (overview: 1-5m, troubleshooting: 10-30s)
- Use `get_dashboard_summary` or `get_dashboard_property` instead of `get_dashboard_by_uid` for large dashboards
- Use patch operations (`uid` + `operations`) for modifying existing dashboards; full JSON only for new dashboards

Multi-signal observability:
- Pair Prometheus time series with Loki logs panels for drill-down
- Enable exemplars on histogram panels to link metrics -> traces
- Use derived fields on Loki to extract trace IDs for logs -> traces linking
- Configure trace-to-logs on Tempo datasource for traces -> logs linking
- Design dashboard hierarchy: Fleet Overview -> Service Dashboard -> Explore (ad-hoc)

OTel metric naming:
- OTel metrics use dot-separated names that become underscores in Prometheus
- Unit suffixes are appended automatically (e.g., `_seconds`, `_bytes`, `_ratio`)
- Type suffixes are appended automatically (`_total` for counters, `_bucket`/`_count`/`_sum` for histograms)
- Do not double-convert units — if the metric has `_seconds` suffix, set the Grafana panel unit to seconds
- Resource attributes live in `target_info` unless promoted; use `* on(instance) group_left() target_info` for joins
