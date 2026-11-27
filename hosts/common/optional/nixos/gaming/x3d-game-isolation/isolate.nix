# x3d-game-isolate split <game-cpus> | release: the root half, run through sudo; while a game runs, system services leave its cores and only its threads keep most of the V-Cache.
{
  writeShellApplication,
  coreutils,
  gawk,
  systemd,
  util-linux,
  cacheCcd,
  cpuRoot ? "/sys/devices/system/cpu",
  resctrlRoot ? "/sys/fs/resctrl",
  # May add its own threads to the game's cache group, so the watcher needs no root for that.
  group,
}:
writeShellApplication {
  name = "x3d-game-isolate";
  runtimeInputs = [coreutils gawk systemd util-linux];
  text = ''
    shopt -s inherit_errexit
    ${builtins.readFile ./cpu-lists.bash}
    cpus="${cpuRoot}"
    resctrl="${resctrlRoot}"

    usage() {
      echo "usage: x3d-game-isolate split <game-cpus> | release" >&2
      exit 2
    }

    refuse() {
      echo "x3d-game-isolate: refusing: $*" >&2
      exit 1
    }

    # Sets cache to the V-Cache CPUs; empty on a CPU without a cache CCD.
    cache_cpus() {
      local split status=0
      split=$("${cacheCcd}") || status=$?
      cache=""
      [ "$status" -ne 3 ] || return 0
      [ "$status" -eq 0 ] || return "$status"
      read -r cache _ <<<"$split"
    }

    # fence_system <cpus>: tries both units, then fails if either could not be set.
    fence_system() {
      local unit failed=0
      for unit in system.slice init.scope; do
        systemctl set-property --runtime "$unit" AllowedCPUs="$1" || {
          echo "x3d-game-isolate: could not set AllowedCPUs=$1 on $unit" >&2
          failed=1
        }
      done
      return "$failed"
    }

    # Sets domain (the V-Cache's L3 id) and full, low and high way masks: the game's group gets the top three quarters.
    cache_ways() {
      local first bits=0 m
      first=''${cache%%[,-]*}
      domain=$(cat "$cpus/cpu$first/cache/index3/id")
      full=$((16#$(cat "$resctrl/info/L3/cbm_mask")))
      for ((m = full; m > 0; m >>= 1)); do bits=$((bits + (m & 1))); done
      [ "$bits" -ge 4 ] || return 1
      low=$(((1 << (bits / 4)) - 1))
      high=$((full & ~low))
    }

    partition_cache() {
      mountpoint -q "$resctrl" || mount -t resctrl resctrl "$resctrl"
      if [ ! -d "$resctrl/info/L3" ]; then
        echo "x3d-game-isolate: this CPU cannot partition its L3; isolating by cores only" >&2
        return 0
      fi
      if ! cache_ways; then
        echo "x3d-game-isolate: the L3 has too few ways to split; isolating by cores only" >&2
        return 0
      fi
      mkdir -p "$resctrl/game"
      chgrp "${group}" "$resctrl/game/tasks"
      chmod g+w "$resctrl/game/tasks"
      printf 'L3:%s=%x\n' "$domain" "$high" >"$resctrl/game/schemata"
      printf 'L3:%s=%x\n' "$domain" "$low" >"$resctrl/schemata"
    }

    unpartition_cache() {
      mountpoint -q "$resctrl" && [ -d "$resctrl/info/L3" ] || return 0
      cache_ways || return 0
      printf 'L3:%s=%x\n' "$domain" "$full" >"$resctrl/schemata"
    }

    split() {
      local game=$1 online other
      is_cpu_list "$game" || usage
      cache_cpus
      # A CPU without a cache CCD has nothing to isolate.
      [ -n "$cache" ] || return 0
      within_cpus "$game" "$cache" || refuse "$game is not within the V-Cache CPUs $cache"
      online=$(cat "$cpus/online")
      other=$(without_cpus "$online" "$game")
      [ -n "$other" ] || refuse "$game would leave system services no CPU"
      fence_system "$other"
      partition_cache
    }

    release() {
      local failed=0
      fence_system "" || failed=1
      cache_cpus
      if [ -n "$cache" ]; then unpartition_cache || failed=1; fi
      return "$failed"
    }

    case "''${1:-}" in
      split)
        [ "$#" -eq 2 ] || usage
        split "$2"
        ;;
      release)
        [ "$#" -eq 1 ] || usage
        release
        ;;
      *) usage ;;
    esac
  '';
}
