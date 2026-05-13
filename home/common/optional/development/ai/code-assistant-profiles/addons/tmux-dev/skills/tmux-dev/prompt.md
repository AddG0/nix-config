---
description: Runs dev servers, log tails, test watchers, and other long-lived commands in a shared tmux session the user can watch. Use when starting a server, tailing logs, or watching tests.
allowed-tools:
  - Bash
  - Read
---

## Current state

Project root and resolved session name:
!`root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; name="$(basename "$root" | tr '.:' '__')"; echo "root: $root"; echo "session: $name"`

tmuxinator config in this project (if any):
!`ls .tmuxinator.yml tmuxinator.yml .tmuxinator/*.yml 2>/dev/null || echo "(none)"`

tmuxinator projects in user config (if any):
!`ls ~/.tmuxinator/*.yml 2>/dev/null || echo "(none)"`

All running tmux sessions:
!`tmux ls 2>/dev/null || echo "(no tmux server running)"`

Windows in this project's session (if it already exists):
!`name="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" | tr '.:' '__')"; tmux list-windows -t "$name" -F '#{window_index}: #{window_name}' 2>/dev/null || echo "(session not running)"`

If the project's session already exists with the right layout, skip bootstrap.

## Scope

Out of scope: one-shot commands whose output is only needed for parsing (use Bash); commands that must block until they finish (use Bash); remote sessions where the user can't attach to the local tmux server.

## Session naming

Throughout this skill, `<session>` means the project-specific session name, resolved in this order:

1. **tmuxinator config in project root** (`.tmuxinator.yml`, `tmuxinator.yml`, or `.tmuxinator/<name>.yml`) — use the `name:` field from the YAML, or the filename without `.yml`.
2. **tmuxinator config in user dir** (`~/.tmuxinator/<x>.yml`) where `<x>` matches the project basename — use `<x>`.
3. **No tmuxinator** — use `basename "$(git rev-parse --show-toplevel || pwd)"`, with `.` and `:` replaced by `_`.

Never use a hardcoded name like `dev`. One session per project keeps multi-project work from colliding.

## Window layout

When bootstrapping without tmuxinator, the default layout:

| Target              | Purpose                                                                       |
| ------------------- | ----------------------------------------------------------------------------- |
| `<session>:scratch` | starting window; ad-hoc commands that need shared visibility                  |
| `<session>:server`  | foreground process the user wants to watch (`pnpm dev`, `cargo run`, ...)     |
| `<session>:logs`    | tails of output produced by the `server` window (`tail -F app.log`, etc.)     |

Address panes by `<session>:<window>` for the active pane, or `<session>:<window>.<index>` for a specific pane in a multi-pane window.

## Bootstrap

**If a tmuxinator config covers this project:**

1. `tmux has-session -t <session> 2>/dev/null` — already running, you're done.
2. Else: `tmuxinator start <session>` — creates and detaches per the YAML. Tell the user to run `t a -t <session>`.
3. Trust the YAML's window layout; don't add windows on top of it. The `## Window layout` table above does not apply.

**If no tmuxinator config:**

1. `tmux has-session -t <session> 2>/dev/null` — check.
2. If missing, ask the user before creating. If approved:
   ```
   tmux new-session -d -s <session> -n scratch
   tmux new-window  -t <session> -n server
   tmux new-window  -t <session> -n logs
   tmux select-window -t <session>:scratch
   ```
   `new-window` switches focus, so the trailing `select-window` is what makes `scratch` the window the user lands on after `t a -t <session>`.
3. Tell the user to run `t a -t <session>` in a spare terminal.

## Sending Commands

```
tmux send-keys -t <session>:<window> '<command>' Enter
```

- Quote the command. Single quotes prevent the local shell from expanding it before tmux sees it.
- `Enter` is tmux's literal token for return — don't put `\n` in the command string.
- For multi-line input or heredocs, write to a tempfile and send the path instead. `send-keys` is line-oriented.

## Reading Output

```
tmux capture-pane -t <session>:<window> -p -S -500
```

- `-p` prints to stdout (default copies to a tmux buffer).
- `-S -N` includes the last N lines of scrollback. Raise for verbose runs.
- For long output, redirect inside the pane (`<cmd> 2>&1 | tee /tmp/run.log`) and read the file with the Read tool. `capture-pane` is for live observation, not archives.

## Stopping Commands

Interrupt the foreground process in a pane:

```
tmux send-keys -t <session>:<window> C-c
```

- `C-c` is the literal tmux token for Ctrl-C; do not type the actual control character.
- Never kill panes or windows the user created. Only kill panes you opened yourself, and confirm first.
- To clear a pane visually: `tmux send-keys -t <session>:<window> 'clear' Enter`. Don't kill the pane to "reset" it.

## Common Workflows

### Dev server + log tail

```
tmux send-keys -t <session>:server 'pnpm dev' Enter
tmux send-keys -t <session>:logs   'tail -F app.log' Enter
```

Capture either pane to check recent output without leaving the chat.

### Nix services

```
tmux send-keys -t <session>:server 'nix run .#services' Enter
```

### Test watcher

```
tmux send-keys -t <session>:scratch 'pnpm test --watch' Enter
```

After the user saves a file, capture the pane to read the new test results.

## Notes

- The tmux server the user attaches to must be the one Claude is running against. If `t ls` from the user's terminal lists different sessions than the "Current state" section above, you're talking to different servers — compare socket paths with `tmux -L <socket> ls`.
- Prefer Bash for short commands whose output you need to parse — capture buffers contain ANSI escape codes.
