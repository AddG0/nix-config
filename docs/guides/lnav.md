# lnav

Log viewer with format auto-detection, regex/SQL filtering, and a stylix-themed
UI. Reads stdin, so pipe logs straight in.

## Launch

```bash
lnav /var/log/foo.log              # a file
stern <app> -o raw | lnav          # k8s logs (auto-detects shq-java / shq-node)
```

Custom formats live in `~/.config/lnav/formats/installed/`. lnav picks the
matching format automatically; the format name shows in the bottom status bar.

## Movement

| Key | Action |
|-----|--------|
| `j` / `k` | down / up a line |
| `Space` / `b` | down / up a page |
| `Ctrl+D` / `Ctrl+U` | down / up a half page |
| `g` / `G` | top / bottom |
| `h` / `l` | left / right a half page |
| `H` / `L` | left / right 10 columns |

## Jumping

| Key | Action |
|-----|--------|
| `e` / `E` | next / prev error |
| `w` / `W` | next / prev warning |
| `s` / `S` | next / prev slowdown (log-rate spike) |
| `o` / `O` | next / prev message with same opid |
| `f` / `F` | next / prev file |
| `u` / `U` | next / prev bookmark |
| `{` / `}` | move between sections / partitions |

## Time navigation

| Key | Action |
|-----|--------|
| `d` / `D` | forward / back 24 hours |
| `0` / `)` | next / prev day |
| `1`–`6` | jump to Nth 10-minute mark of the hour |
| `7` / `8` | prev / next minute |
| `r` / `R` | jump by last-used relative time |

## Search, filter, query

| Key | Action |
|-----|--------|
| `/` | regex search |
| `n` / `N` | next / prev search hit |
| `:` | command mode (e.g. `:filter-out`, `:filter-in`) |
| `;` | SQL query mode |
| `\|` | run an lnav script |
| `Ctrl+F` | toggle all filters on/off |

## Marks & clipboard

| Key | Action |
|-----|--------|
| `m` | mark / unmark focused line |
| `M` | mark range to top |
| `J` / `K` | extend mark down / up |
| `c` | copy marked lines to clipboard |
| `C` | clear all marks |

## Display toggles

| Key | Action |
|-----|--------|
| `P` | pretty-print |
| `t` | text-file view |
| `i` / `I` | histogram (`I` = time-synced) |
| `v` / `V` | SQL results view (`V` = synced to log line) |
| `p` | parser results for focused line (shows extracted fields) |
| `x` | hide / show fields |
| `Ctrl+W` | word-wrap |
| `T` | elapsed time between lines |
| `=` | pause / unpause loading |

## Session

| Key | Action |
|-----|--------|
| `?` / `F1` | help |
| `q` / `Q` | back / quit (`Q` syncs view times) |
| `a` / `A` | restore last-closed view |
| `Ctrl+R` | reset session (filters, marks, hidden fields) |

## Common commands (`:`)

| Command | Action |
|---------|--------|
| `:filter-out <regex>` | hide matching lines (e.g. `:filter-out Health/Check`) |
| `:filter-in <regex>` | show only matching lines |
| `:comment <text>` | annotate the focused line |
| `:reset-session` | clear all filters and marks |

## SQL (`;`)

Query format-specific fields on the **format table** (e.g. `shq_java`), not
`all_logs` (which only has common columns).

```sql
-- transactions ranked by line count + errors
SELECT "contextMap/transactionId" AS txn, count(*), sum(log_level='error')
FROM shq_java GROUP BY txn ORDER BY 2 DESC;

-- confirm which format is active
SELECT DISTINCT log_format FROM all_logs;
```
