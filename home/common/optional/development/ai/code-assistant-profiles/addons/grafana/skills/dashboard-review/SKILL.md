---
name: dashboard-review
description: Review a Grafana dashboard against observability best practices and suggest improvements. Checks layout, queries, thresholds, variables, documentation, and performance.
argument-hint: "[dashboard-uid] — UID of the dashboard to review"
---

# Dashboard Review

Review the Grafana dashboard specified by `$ARGUMENTS`.

## Steps

1. **Fetch overview** using `get_dashboard_summary` with the provided UID. If no UID given, ask the user or use `search_dashboards` to find it.

2. **Inspect queries** using `get_dashboard_panel_queries` to understand what each panel queries.

3. **Inspect specific panels** using `get_dashboard_property` with JSONPaths like:
   - `$.panels[*].title` — all panel titles
   - `$.panels[*].gridPos` — layout positions
   - `$.panels[*].description` — panel descriptions
   - `$.templating.list` — template variables
   - `$.graphTooltip` — shared crosshair setting

4. **Spot-check queries** using `query_prometheus` (instant) on 2-3 key panel queries to verify they return data. For Loki panels, use `query_loki_logs` or `query_loki_stats`.

5. **Evaluate against these criteria**, scoring each as pass/warn/fail:

### Layout & Hierarchy
- [ ] Summary stats (stat/gauge) in top row
- [ ] Trends (time series) in middle rows
- [ ] Detail (tables/logs) at bottom
- [ ] Collapsible rows with descriptive titles
- [ ] Panel count under 20
- [ ] Panels sized proportionally to importance

### Framework & Story
- [ ] Follows a methodology (RED, USE, or Golden Signals)
- [ ] Answers one clear question
- [ ] Panels ordered general-to-specific

### Color & Thresholds
- [ ] Stat/gauge panels have meaningful thresholds
- [ ] Colors encode meaning (green/amber/red), not decoration
- [ ] Background color mode on stat panels

### Variables & Filtering
- [ ] Template variables for key dimensions
- [ ] Variables labeled for readability
- [ ] No high-cardinality repeating panels

### Query Quality
- [ ] Uses `$__rate_interval` in rate()/increase()
- [ ] Explicit `sum by ()` grouping
- [ ] No raw counter queries without rate()
- [ ] Key queries return data (verified via spot-check)

### Documentation
- [ ] Header text panel or dashboard description explaining purpose
- [ ] Panel descriptions present on most panels
- [ ] Shared crosshair enabled (graphTooltip: 1)

### Performance
- [ ] Refresh rate matches data cadence
- [ ] No unnecessary duplicate queries across panels

6. **Output a report** with:
   - Overall score (X/24 checks passed)
   - Top 3 priority improvements with specific suggestions
   - Offer to apply fixes automatically via `update_dashboard` patch operations
