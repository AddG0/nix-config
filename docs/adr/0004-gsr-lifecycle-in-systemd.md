---
status: accepted
date: 2026-10-11
---

# GPU Screen Recorder's lifecycle is owned by systemd units, not a bash supervisor

## Context and Problem Statement

The replay buffer (`modules/home/nixos/services/gpu-screen-recorder.nix`) ran
GSR under a bash supervisor. The supervisor polled `wlr-randr` and `udevadm`
for the monitor, read GSR's output through a coproc, and killed GSR when it
saw known log lines. On demon, two failures got past it on 2026-10-10:

- xdph switched GSR's portal stream to CPU (SHM) buffers. GSR logged
  `new state: "error"` and kept encoding the last frame for seven hours, because
  the supervisor's log patterns did not include that line.
- Turning DP-3 off crashed xdph. GSR's own 3-second paused-capture restart
  re-opened its portal session before the 10-second poll noticed. The picker
  then showed an interactive dialog, and GSR blocked on it ignoring SIGTERM, so
  the supervisor sat in `wait` for ten hours.

Portal capture has to stay: DP-3 runs HDR, and direct capture records it
oversaturated.

## Decision Drivers

- A dead capture must be caught by its state, not by recognising a log line.
- Monitor changes must be acted on before GSR's 3-second internal restart.
- A GSR stuck in its portal wait must still be stoppable.
- Less custom process management to keep correct.

## Considered Options

1. systemd owns the process; Hyprland events gate it; a timer checks the stream.
2. Keep the bash supervisor and patch each gap (more patterns, kill escalation).
3. Drop portal mode and capture DP-3 directly (`-w DP-3`).

## Decision Outcome

Chosen option: 1.

- `gpu-screen-recorder-replay.service` execs GSR directly with `Restart=always`
  and `TimeoutStopSec=5s`, so systemd sends SIGKILL to a GSR that ignores SIGTERM.
- `ExecCondition` skips a start while the configured monitor is disconnected.
- `gsr-monitor-gate.service` listens on Hyprland's event socket and starts or
  stops the recorder on `monitoradded`/`monitorremoved`.
- `gsr-health.timer` restarts GSR when its portal video stream has no pipewire
  link on two checks 10 s apart.
- The xdph picker treats a running GSR without a linked stream as the requester,
  instead of a GSR younger than 30 s.

### Consequences

- Good: one state-based health check covers stream errors, an SHM fallback and a
  dropped link, including failures not seen yet.
- Good: the module no longer depends on `wlr-randr`, `udevadm`, `gawk` or a coproc.
- Bad: live monitor gating is Hyprland-only. On other compositors the unit is
  only gated by `ExecCondition` at start, where the old supervisor polled
  `wlr-randr` on any wlroots compositor.
- Bad: a dead stream is caught within about 40 s, not instantly.
- Neutral: the health timer only runs in portal mode, because direct capture has
  no pipewire video stream to inspect.

## Pros and Cons of the Options

### 2. Patch the bash supervisor

- Good: keeps polling that works on any wlroots compositor.
- Bad: each new failure needs another log pattern, and polling still loses the
  race to GSR's 3-second restart.

### 3. Capture DP-3 directly

- Good: removes xdph, the picker and restore tokens, where all of the failures
  started.
- Bad: needs HDR clips (`hevc_hdr`, tone-mapped later for sharing) or HDR turned
  off on DP-3.
