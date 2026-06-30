# herdr

Agent-aware terminal multiplexer, tmux-like. Source:
[`home/common/optional/development/herdr.nix`](../../home/common/optional/development/herdr.nix).
Prefix is `Ctrl+B`; keybinds mirror the [tmux](../../home/common/core/cli/tmux/)
setup. Model: `workspace` › `tab` › `pane` (≈ session › window › pane). New
panes/tabs inherit the source cwd.

## Launch

```bash
herdr                       # launch or attach the persistent session
herdr --session <name>      # use/create a named session
herdr status                # client + server status
```

## Workspaces

| Key | Action |
|-----|--------|
| `prefix s` / `prefix S` | picker / new |
| `prefix $` | rename |
| `prefix Shift+D` | close |

## Tabs

| Key | Action |
|-----|--------|
| `prefix c` | new (inherits cwd) |
| `prefix ,` / `prefix &` | rename / close |
| `prefix p` / `prefix n` | previous / next |
| `prefix 1`–`9` | jump to tab |

## Panes

| Key | Action |
|-----|--------|
| `prefix \|` / `prefix -` | split left-right / top-bottom |
| `Alt+←↓↑→` | focus |
| `prefix Tab` / `prefix Shift+Tab` | cycle |
| `prefix x` / `prefix z` | close / zoom |
| `prefix Shift+R` | resize mode |
| `prefix e` | edit scrollback |

## Session & misc

| Key | Action |
|-----|--------|
| `prefix d` / `prefix r` | detach / reload config |
| `prefix b` / `prefix ?` | toggle sidebar / help |
| `prefix Shift+T` | settings |
| `prefix Alt+G` | lazygit pane |
| `prefix Shift+G` | new git worktree |

## CLI (socket API)

```bash
herdr workspace create [--cwd PATH] [--label TEXT] [--focus]
herdr workspace list | focus <id> | rename <id> <label> | close <id>
herdr pane split|focus|resize|swap|neighbor --direction right|down|left|right|up|down
herdr tab ... | herdr agent list | herdr server reload-config | herdr server stop
```

## Notes

- **Updates**: self-update is disabled on Nix; herdr only notifies. Update via
  `just rebuild` then `herdr server stop` (relaunch runs the new binary).
- **No keybind** (use CLI): resize-by-key, reorder tabs, swap panes, copy-mode,
  floating panes (herdr panes are tiled).
- **Key syntax**: some punctuation is named (`minus`, `comma`, `ampersand`); the
  rest is literal (`|`, `$`). `pipe`/`bar`/`dollar` are rejected.
