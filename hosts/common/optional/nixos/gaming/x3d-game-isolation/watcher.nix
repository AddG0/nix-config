# x3d-game-isolation-watcher watch | reconcile | release: while gamemode has a game, gives it as many V-Cache cores as it uses and most of that cache; everything but the compositor and Steam client runs on the rest.
{
  writeShellApplication,
  coreutils,
  findutils,
  gawk,
  glib,
  gnugrep,
  gnused,
  procps,
  systemd,
  util-linux,
  cacheCcd,
  isolate,
  sudo,
  procRoot ? "/proc",
  cgroupRoot ? "/sys/fs/cgroup",
  cpuRoot ? "/sys/devices/system/cpu",
  resctrlRoot ? "/sys/fs/resctrl",
  # The game never has fewer V-Cache cores than this; Rocket League needs two to three.
  minCores ? 4,
  # Another core while the game's cores run busier than this share, or its threads wait longer than this percent of the time.
  growBusy ? 0.85,
  growWaiting ? 5,
  # One core fewer while the game would stay under this share without it.
  shrinkBusy ? 0.7,
  retryPendingAfter ? 2,
  retryFailedAfter ? 5,
  # How often the watcher checks a running game.
  sizeEvery ? 1,
  # The shortest stretch of load the game's cores are sized on; a resize starts a new one.
  sizeWindow ? 5,
}:
writeShellApplication {
  name = "x3d-game-isolation-watcher";
  runtimeInputs = [coreutils findutils gawk glib gnugrep gnused procps systemd util-linux];
  text = ''
    shopt -s inherit_errexit
    ${builtins.readFile ./cpu-lists.bash}
    proc="${procRoot}"
    cgroups="${cgroupRoot}"
    cpus="${cpuRoot}"
    resctrl="${resctrlRoot}"
    uid=$(id -u)
    session=/user.slice/user-$uid.slice/user@$uid.service
    games=$session/game.slice
    # The game's CPU time and stall time at the previous pass, to measure its load between passes.
    usage_sample=''${XDG_RUNTIME_DIR:?the watcher runs as a user service, which sets XDG_RUNTIME_DIR}/x3d-game-isolation.usage

    usage() {
      echo "usage: x3d-game-isolation-watcher watch | reconcile | release" >&2
      exit 2
    }

    game_pids() {
      local listing
      listing=$(gdbus call --session --dest com.feralinteractive.GameMode \
        --object-path /com/feralinteractive/GameMode --method com.feralinteractive.GameMode.ListGames)
      case $listing in "(@a(io) [],)") return 0 ;; esac
      grep -oE '\([0-9]+, objectpath' <<<"$listing" | grep -oE '[0-9]+' || {
        echo "x3d-game-isolation: cannot read gamemode's ListGames reply: $listing" >&2
        return 1
      }
    }

    cgroup_of() {
      [ -r "$proc/$1/cgroup" ] || return 0
      sed -n 's/^0:://p' "$proc/$1/cgroup"
    }

    parent_of() {
      [ -r "$proc/$1/status" ] || return 0
      awk '/^PPid:/ {print $2}' "$proc/$1/status"
    }

    # The CPUs a cgroup is fenced to; empty when it may use every CPU.
    fence_of() {
      [ -r "$cgroups$1/cpuset.cpus" ] || return 0
      cat "$cgroups$1/cpuset.cpus"
    }

    # The V-Cache CCD's physical cores in order, one CPU list per core ("0,16").
    physical_cores() {
      local list cpu siblings core seen=" "
      list=$(expand_cpus "$cache")
      for cpu in $list; do
        siblings=$(cat "$cpus/cpu$cpu/topology/thread_siblings_list")
        core=$(expand_cpus "$siblings" | compress_cpus)
        [[ $seen == *" $core "* ]] && continue
        seen+="$core "
        echo "$core"
      done
    }

    # first_cores <n>: the CPUs of the first <n> physical cores.
    first_cores() {
      printf '%s\n' "''${cores[@]:0:$1}" | tr ',' '\n' | while read -r part; do expand_cpus "$part"; done | compress_cpus
    }

    # How many physical cores the game has now, or the minimum when it has none of the V-Cache CCD yet.
    current_cores() {
      local fence n=0 core
      fence=$(fence_of "$games")
      if [ -n "$fence" ] && within_cpus "$fence" "$cache"; then
        for core in "''${cores[@]}"; do
          if within_cpus "$core" "$fence"; then n=$((n + 1)); fi
        done
      fi
      [ "$n" -ge ${toString minCores} ] || n=${toString minCores}
      echo "$n"
    }

    # sized_cores <n>: one core more while the game's cores run full or its threads wait, one fewer while it would stay well under.
    sized_cores() {
      local n=$1 now usage stall=0 previous=""
      [ -r "$cgroups$games/cpu.stat" ] || { echo "$n"; return; }
      now=$(date +%s.%N)
      usage=$(awk '/^usage_usec/ {print $2}' "$cgroups$games/cpu.stat")
      if [ -r "$cgroups$games/cpu.pressure" ]; then
        stall=$(awk '/^some/ {split($5, a, "="); print a[2]}' "$cgroups$games/cpu.pressure")
      fi
      [ ! -r "$usage_sample" ] || previous=$(cat "$usage_sample")
      if [ -n "$previous" ] && awk -v now="$now" -v then="''${previous%% *}" -v window=${toString sizeWindow} 'BEGIN {exit !(now >= then && now - then < window)}'; then
        echo "$n"
        return
      fi
      echo "$now $usage $stall" >"$usage_sample"
      awk -v n="$n" -v max="''${#cores[@]}" -v min=${toString minCores} -v now="$now" -v usage="$usage" -v stall="$stall" \
        -v previous="$previous" -v grow_busy=${toString growBusy} -v grow_waiting=${toString growWaiting} -v shrink_busy=${toString shrinkBusy} '
        BEGIN {
          split(previous, p, " ")
          seconds = now - p[1]
          # A first pass, a recreated slice or a stepped clock gives no reading.
          if (previous == "" || seconds <= 0 || usage < p[2] || stall < p[3]) { print n; exit }
          busy = (usage - p[2]) / 1e6 / seconds / n
          waiting = 100 * (stall - p[3]) / 1e6 / seconds
          if ((busy > grow_busy || waiting > grow_waiting) && n < max) n++
          else if (n > min && busy * n / (n - 1) < shrink_busy) n--
          print n
        }'
    }

    # adopt <slice> <scope> <lister> [args...]: moves the lister's processes into a new scope, listing afresh per attempt as systemd rejects a move naming an exited PID.
    adopt() {
      local slice=$1 scope=$2 attempt error="" listed pids _
      shift 2
      for attempt in 1 2 3; do
        listed=$("$@")
        mapfile -t pids <<<"$listed"
        if [ -z "$listed" ]; then
          echo "x3d-game-isolation: no process left to move into $slice" >&2
          return 1
        fi
        if error=$(busctl --user call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager \
          StartTransientUnit 'ssa(sv)a(sa(sv))' "$scope" fail \
          2 Slice s "$slice" PIDs au "''${#pids[@]}" "''${pids[@]}" 0 2>&1 >/dev/null); then
          for _ in $(seq 20); do
            case $(cgroup_of "''${pids[0]}") in */"$scope") return 0 ;; esac
            sleep 0.1
          done
          echo "x3d-game-isolation: process ''${pids[0]} did not move into $slice" >&2
          return 1
        fi
      done
      echo "x3d-game-isolation: could not move processes into $slice after $attempt attempts: $error" >&2
      return 1
    }

    # game_tree <pid> <cgroup>: the whole cgroup when it is Steam's scope for the game, else <pid> and its descendants in it.
    game_tree() {
      local pid=$1 cg=$2 procs p ppid tree members changed=1
      mapfile -t procs <"$cgroups$cg/cgroup.procs"
      case ''${cg##*/} in
        app-steam-app*.scope)
          printf '%s\n' "''${procs[@]}"
          return
          ;;
      esac
      tree=" $pid "
      while [ "$changed" = 1 ]; do
        changed=0
        for p in "''${procs[@]}"; do
          [[ $tree != *" $p "* ]] || continue
          ppid=$(parent_of "$p")
          if [ -n "$ppid" ] && [[ $tree == *" $ppid "* ]]; then
            tree+="$p "
            changed=1
          fi
        done
      done
      read -ra members <<<"$tree"
      printf '%s\n' "''${members[@]}"
    }

    adopt_game() {
      local pid=$1 cg
      # gamemode also registers launchers that exit within a second.
      [ -d "$proc/$pid" ] || return 0
      cg=$(cgroup_of "$pid")
      case $cg in
        "$games/"*) return 0 ;;
        "$session/"?*) ;;
        *)
          echo "x3d-game-isolation: game $pid runs in ''${cg:-an unreadable cgroup}, outside this user's session; it cannot be moved" >&2
          return 1
          ;;
      esac
      adopt game.slice "x3d-game-$pid.scope" game_tree "$pid" "$cg"
      adopted=1
    }

    # pin_game <cpus>: gamemode pins a game at launch, and a pin taken under another fence keeps it off cores it was given.
    pin_game() {
      local procs p
      procs=$(find "$cgroups$games" -name cgroup.procs -exec cat {} +)
      for p in $procs; do
        # A process can exit between the listing and the call.
        taskset -a -pc "$1" "$p" >/dev/null 2>&1 || [ ! -d "$proc/$p" ] || {
          echo "x3d-game-isolation: could not reset the CPU affinity of game process $p" >&2
          return 1
        }
      done
    }

    # Puts every thread of the game's processes in the cache group the helper set up; threads started later inherit it.
    join_cache_group() {
      local tasks=$resctrl/game/tasks procs p thread
      [ -d "$resctrl/info/L3" ] || return 0
      if [ ! -w "$tasks" ]; then
        echo "x3d-game-isolation: cannot write $tasks, so the game gets the small share of the V-Cache; is this user in the gamemode group?" >&2
        return 1
      fi
      procs=$(find "$cgroups$games" -name cgroup.procs -exec cat {} +)
      for p in $procs; do
        grep -qx "$p" "$tasks" && continue
        for thread in "$proc/$p"/task/*; do
          # A thread that exited since the listing is fine; one still running is not.
          { echo "''${thread##*/}" >>"$tasks"; } 2>/dev/null || [ ! -d "$thread" ] || {
            echo "x3d-game-isolation: could not add thread ''${thread##*/} of game process $p to $tasks" >&2
            return 1
          }
        done
      done
    }

    # steam_unit <steam pid> <cgroup>: Steam first, since adopt waits on the first PID; grep exits 1 when Steam is alone in its unit.
    steam_unit() {
      echo "$1"
      grep -vxF "$1" "$cgroups$2/cgroup.procs" || true
    }

    # The game calls into the Steam client every frame, so it must not wait behind the session's work.
    steam_beside_compositor() {
      local steam cg
      steam=$(pgrep -u "$uid" -x steam) || return 0
      steam=''${steam%%$'\n'*}
      cg=$(cgroup_of "$steam")
      case $cg in
        "$session/session.slice/"*) return 0 ;;
        "$session/"?*) adopt session-graphical.slice "x3d-steam-client-$steam.scope" steam_unit "$steam" "$cg" ;;
        *) return 0 ;;
      esac
    }

    # set_fence <cgroup> <unit> <cpus>: sets the unit's AllowedCPUs unless already there, then checks the kernel applied it.
    set_fence() {
      local applied
      [ "$(fence_of "$1")" != "$3" ] || return 0
      systemctl --user set-property --runtime "$2" AllowedCPUs="$3" || {
        echo "x3d-game-isolation: could not set AllowedCPUs=$3 on $2; retrying next pass" >&2
        return 1
      }
      applied=$(fence_of "$1")
      [ "$applied" = "$3" ] || {
        echo "x3d-game-isolation: $2 runs on '$applied' after AllowedCPUs=$3; cpuset is delegated to the session only after logging in again" >&2
        return 1
      }
    }

    # The units the session's CPU split applies to: every direct child of the user manager but the compositor's slice and the game's.
    session_units() {
      local child unit
      for child in "$cgroups$session"/*/; do
        unit=''${child%/}
        unit=''${unit##*/}
        case $unit in session.slice | game.slice) ;; *) echo "$unit" ;; esac
      done
    }

    # fence_session <cpus>: fences every session unit, trying them all; empty <cpus> gives them every CPU back.
    fence_session() {
      local units unit failed=0
      units=$(session_units)
      for unit in $units; do
        set_fence "$session/$unit" "$unit" "$1" || failed=1
      done
      return "$failed"
    }

    # Whether the root helper's V-Cache split is in place: some L3 domain of the default group holds fewer than every way.
    cache_split() {
      [ -r "$resctrl/schemata" ] && [ -r "$resctrl/info/L3/cbm_mask" ] || return 1
      awk -v full="$(cat "$resctrl/info/L3/cbm_mask")" '
        /^ *L3:/ {
          sub(/^ *L3:/, ""); n = split($0, domains, ";")
          for (i = 1; i <= n; i++) { split(domains[i], kv, "="); if (strtonum("0x" kv[2]) != strtonum("0x" full)) split_found = 1 }
        }
        END { exit !split_found }' "$resctrl/schemata"
    }

    # system_split_to <cpus>: whether system services run on <cpus> and the V-Cache is split, or cannot be on this CPU.
    system_split_to() {
      [ "$(fence_of /system.slice)" = "$1" ] && [ "$(fence_of /init.scope)" = "$1" ] || return 1
      [ -d "$resctrl/info" ] || return 1
      [ -d "$resctrl/info/L3" ] || return 0
      cache_split
    }

    system_split() {
      [ -n "$(fence_of /system.slice)" ] || [ -n "$(fence_of /init.scope)" ] || cache_split
    }

    game_still_running() {
      local procs
      [ -d "$cgroups$games" ] || return 1
      procs=$(find "$cgroups$games" -name cgroup.procs -exec cat {} +)
      [ -n "$procs" ]
    }

    release() {
      local failed=0
      fence_session "" || failed=1
      if system_split; then "${sudo}" -n "${isolate}" release || failed=1; fi
      rm -f "$usage_sample"
      return "$failed"
    }

    # isolate_game <pids>: sizes the game's cores, moves it there and everything else to the rest; a resize overlaps for one pass at most.
    isolate_game() {
      local n game online rest pid before failed=0 adopted=0
      n=$(current_cores)
      n=$(sized_cores "$n")
      game=$(first_cores "$n")
      online=$(cat "$cpus/online")
      rest=$(without_cpus "$online" "$game")
      if [ -z "$game" ] || [ -z "$rest" ]; then
        echo "x3d-game-isolation: no usable split of '$online' (game '$game', rest '$rest'); leaving every fence as it is" >&2
        return 1
      fi

      system_split_to "$rest" || "${sudo}" -n "${isolate}" split "$game"
      # The game moves before the session is fenced: fencing first would trap it on the busy cores.
      for pid in $1; do
        adopt_game "$pid"
      done
      before=$(fence_of "$games")
      set_fence "$games" game.slice "$game"
      if [ "$adopted" = 1 ] || [ "$before" != "$game" ]; then pin_game "$game"; fi
      join_cache_group || failed=1
      steam_beside_compositor || failed=1
      fence_session "$rest" || failed=1
      return "$failed"
    }

    # One pass towards what should be isolated now; prints idle, playing, or pending while the game's processes exit.
    reconcile() {
      local pids split status=0 found cores
      split=$("${cacheCcd}") || status=$?
      if [ "$status" -eq 3 ]; then
        echo idle
        return
      fi
      [ "$status" -eq 0 ] || return "$status"
      read -r cache _ <<<"$split"

      pids=$(game_pids)
      if [ -z "$pids" ]; then
        # Proton's helpers outlive the game's registration by a few seconds.
        if game_still_running; then
          echo pending
          return
        fi
        release
        echo idle
        return
      fi

      found=$(physical_cores)
      mapfile -t cores <<<"$found"
      if [ "''${#cores[@]}" -lt ${toString minCores} ] || [ -z "''${cores[0]}" ]; then
        echo "x3d-game-isolation: found ''${#cores[@]} V-Cache cores in '$cache', fewer than the ${toString minCores} a game needs" >&2
        return 1
      fi
      isolate_game "$pids"
      echo playing
    }

    # Lines whenever a game registers or leaves, or gamemoded starts or stops.
    gamemode_events() {
      gdbus monitor --session --dest com.feralinteractive.GameMode --object-path /com/feralinteractive/GameMode |
        grep --line-buffered -E 'GameRegistered|GameUnregistered|is owned by|does not have an owner'
    }

    # Reconciles on each gamemode event; a pass that left work behind schedules the next one itself.
    watch() {
      local state wait status
      exec 3< <(gamemode_events)
      while :; do
        state=$("$0" reconcile) || {
          echo "x3d-game-isolation: reconcile failed (exit $?); retrying in ${toString retryFailedAfter}s" >&2
          state=failed
        }
        case $state in
          idle) wait="" ;;
          playing) wait=${toString sizeEvery} ;;
          pending) wait=${toString retryPendingAfter} ;;
          *) wait=${toString retryFailedAfter} ;;
        esac
        status=0
        if [ -n "$wait" ]; then read -r -t "$wait" -u 3 _ || status=$?; else read -r -u 3 _ || status=$?; fi
        # Above 128 is a timeout; anything else is the end of the stream, after which no game would be noticed.
        if [ "$status" -ne 0 ] && [ "$status" -le 128 ]; then
          echo "x3d-game-isolation: gamemode's signal stream ended; exiting so systemd restarts the watcher" >&2
          exit 1
        fi
      done
    }

    [ "$#" -eq 1 ] || usage
    case $1 in
      watch) watch ;;
      reconcile) reconcile ;;
      release) release ;;
      *) usage ;;
    esac
  '';
}
