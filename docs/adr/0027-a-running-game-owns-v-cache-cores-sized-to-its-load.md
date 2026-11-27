---
status: accepted
date: 2026-11-25
---

# A running game owns V-Cache cores sized to its load

## Context and Problem Statement

demon's 9950X3D has its 96 MB V-Cache on one CCD (CPUs 0-7,16-23). Rocket
League hitched while nix builds, Ollama and AI agents kept the machine at load
60–100, and the user will not stop that work to play. gamemode pins the game to
the cache CCD but leaves everything else there too, and its renice is a no-op
across cgroups.

MangoHud frame-time logs (`docs/work/x3d-game-isolation/design.md`) showed:

- CPU priority does not fix it: `CPUWeight=10000` for the game and
  `CPUWeight=idle` for background work left p99 at ~10.5 ms under load.
- Moving the background work off the cache CCD does: p99 10.5 → 5.3 ms under
  stress, and with real load p99.9 4.6 ms with no frame over 33 ms.
- The compositor and the Steam client must stay off the busy CCD: on it, long
  frames came back (Steam: 0 → 17 per minute; both: 0 → 14).

Later runs under a 32-worker stress load (render-thread run-queue wait from
`/proc/<tid>/schedstat`, frame times from MangoHud after the first 15 s):

| Setup | FPS | p99 | p99.9 | Background got |
|---|---|---|---|---|
| Whole V-Cache CCD for the game, everything else on the other CCD | 550 | 10.1 ms | 21.8 ms | 9.2 cores |
| No fence, L3 split by resctrl (game 12 of 16 ways), game at weight 10000 | 329 | 7.5 ms | 13.7 ms | 23.9 cores |
| The same, background `cpu.idle=1` | 416 | 6.1 ms | 10.7 ms | 21.0 cores |
| The same plus core scheduling on the game | very laggy | | | 21.4 cores |
| **Game owns 4 V-Cache cores, L3 split, everything else on the rest** | **674** | **2.2 ms** | **2.9 ms** | **17.8 cores** |

Sharing a physical core with background work costs the game frames whatever
its priority: SMT siblings run at the same time, and a woken game thread waits
out the running task's slice.

## Considered Options

1. A user-level watcher following gamemode moves the game into a `game.slice`
   inside the user's session and gives it as many V-Cache cores as its load
   needs (at least 4, grown when its cores run over 85% busy or its threads wait,
   shrunk when it would stay under 70% with one fewer); a root helper fences
   `system.slice` and `init.scope` to every other CPU and splits the V-Cache L3
   with resctrl, three quarters to the game's threads. The Steam client moves
   beside the compositor; every other session unit gets the rest of the CPUs.
2. Option 1 with the whole V-Cache CCD always given to the game.
3. Option 1 with a fixed core count per game, declared in the game config.
4. No fence: L3 split, game at high weight, background idle-class or under core
   scheduling, sharing every core.
5. A cpuset partition: `CPUSetPartition=root` on `game.slice`.
6. A sched_ext scheduler, `scx_lavd` or `scx_layered` with an exclusive game layer.
7. A root helper that adopts the game's PIDs into a top-level slice.
8. Option 1, but the game may also run on the rest of the V-Cache CCD, shared
   with background work at weight 10000 against 100; only its reserved cores
   are exclusive.

## Decision Outcome

Chosen: option 1, in `hosts/common/optional/nixos/gaming/x3d-game-isolation/`.

- Option 2 rejected: it leaves most of the V-Cache CCD idle under a light game
  (11% busy) and measured worse than four owned cores.
- Option 3 rejected: every game needs a setting before it plays well.
- Option 4 rejected: measured 40% fewer frames than option 1; priority cannot
  stop SMT siblings sharing a core, and core scheduling forces the game to wait
  for its sibling.
- Option 5 rejected: no cgroup outside the partition can use its CPUs, so the
  compositor and Steam client would lose them, which run C4 showed costs frames.
- Option 6 rejected for now: `scx_lavd` measured ~500 vs ~700 FPS against BORE;
  `scx_layered` replaces BORE for every task and has no published game data.
- Option 8 rejected: measured worse in two runs (577 and 639 FPS, p99.9 30 and
  9 ms, 83 and 17 frames over 16.7 ms a minute, background 14 and 9 cores)
  than the cap (674 FPS, p99.9 2.9 ms, none, 18 cores). The scheduler does not
  prefer the reserved cores, so the render thread lands on shared ones.
- Option 7 rejected: systemd's `unit_pid_attachable` does not check who owns the
  PIDs, so the helper would have to; the user manager can only move the user's
  own processes, and the user's group may add its own threads to the cache
  group, which the kernel also checks.

### Consequences

- Good: the game keeps its frames under the user's full dev load, while
  background work gets every CPU the game is not using.
- Good: the root helper only takes a CPU list, refused unless it lies within
  the V-Cache CCD, so system services always keep the other CCD.
- Bad: the game's cores grow a second after its load does; a sudden spike runs
  on the cores it had.
- Bad: `Delegate=cpuset` on `user@.service` takes effect only after the user
  logs in again, and resctrl stays mounted once a game has run.
- Bad: kernel threads, IRQs and login sessions (ssh, tty) stay on every CPU.
- Neutral: the watcher resets the game's CPU affinity when it adopts it; a
  gamemode pin taken while the session was fenced would otherwise keep the game
  off its own cores.
- Neutral: outside Steam's per-game `app-steam-app*.scope`, only the gamemode
  client and its descendants are adopted, so a game started from a terminal
  does not drag the terminal along.
