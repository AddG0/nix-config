# sens-convert: find the in-game sensitivity + DPI that best reproduces your
# reference cm/360 in another game. Games expose sensitivity in coarse steps
# (Overwatch only takes whole numbers), so a single fixed DPI rarely lands on
# your exact cm/360 -- this searches the target game's sens steps AND a range
# of DPI values, preferring a DPI near your base (default 1800).
#
# Defaults: source is Valorant, source sens is read live from your Aim Lab
# config (Valorant profile) at Aim Lab's 1600 DPI (the mouseDpi wrapper in
# steam.nix), so the common call is just:
#
#   sens-convert overwatch                 # Aim Lab sens -> Overwatch (decimals)
#   sens-convert overwatch 0.45            # override source sens
#   sens-convert source --from-game val 0.4
{pkgs, ...}: let
  sens-convert = pkgs.writeScriptBin "sens-convert" ''
    #!${pkgs.python3}/bin/python3
    """Convert FPS mouse sensitivity between games, preserving cm/360.

    Defaults: source game is Valorant and the source sens is read live from
    your Aim Lab config at Aim Lab's 1600 DPI, so the common call is just:
    sens-convert overwatch
    """
    import argparse
    import glob
    import json
    import os
    import sys

    # yaw = degrees turned per mouse count at sens=1, dpi=1.
    # step/min/max describe the in-game sensitivity slider granularity.
    GAMES = {
        "overwatch": {"yaw": 0.0066, "step": 0.01, "min": 1.0, "max": 100.0},
        "valorant": {"yaw": 0.07, "step": 0.001, "min": 0.001, "max": 10.0},
        "source": {"yaw": 0.022, "step": 0.01, "min": 0.01, "max": 30.0},
    }
    # Source-engine family (and friends) share the 0.022 yaw constant.
    ALIASES = {
        "ow": "overwatch", "ow2": "overwatch",
        "val": "valorant",
        "cs": "source", "cs2": "source", "csgo": "source",
        "apex": "source", "tf2": "source", "quake": "source",
    }

    SEP = ", "
    AIMLAB_DIR = os.path.expanduser(
        "~/.local/share/Steam/steamapps/compatdata/714010/pfx/drive_c/"
        "users/steamuser/AppData/LocalLow/Statespace/aimlab_tb")

    # ANSI palette slots (themed by the terminal, i.e. stylix). Disabled when
    # output is piped or NO_COLOR is set, so redirected output stays plain.
    if sys.stdout.isatty() and "NO_COLOR" not in os.environ:
        BOLD, DIM, RESET = "\033[1m", "\033[2m", "\033[0m"
        RED, GREEN, YELLOW, CYAN = "\033[31m", "\033[32m", "\033[33m", "\033[36m"
    else:
        BOLD = DIM = RESET = RED = GREEN = YELLOW = CYAN = ""


    def err_color(pct):
        if pct < 0.5:
            return GREEN
        if pct < 2.0:
            return YELLOW
        return RED


    def resolve(name):
        key = ALIASES.get(name.lower(), name.lower())
        if key not in GAMES:
            known = SEP.join(sorted(set(list(GAMES) + list(ALIASES))))
            sys.exit(f"unknown game: {name} (known: {known})")
        return key, GAMES[key]


    def cm360(yaw, sens, dpi):
        return 360.0 / (yaw * sens * dpi) * 2.54


    def snap(value, step, lo, hi):
        snapped = max(lo, min(hi, round(value / step) * step))
        return round(snapped, 6)


    def best_sens(target, game, dpi):
        """Snapped in-game sens at dpi closest to target cm/360, with error %."""
        ideal = 360.0 * 2.54 / (target * game["yaw"] * dpi)
        sens = snap(ideal, game["step"], game["min"], game["max"])
        cm = cm360(game["yaw"], sens, dpi)
        return sens, cm, abs(cm - target) / target * 100.0


    def find_key(obj, key):
        """Recursively search obj for key, re-parsing stringified JSON blobs."""
        if isinstance(obj, str):
            try:
                obj = json.loads(obj)
            except (ValueError, TypeError):
                return None
            return find_key(obj, key)
        if isinstance(obj, dict):
            if key in obj:
                return obj[key]
            for value in obj.values():
                found = find_key(value, key)
                if found is not None:
                    return found
        elif isinstance(obj, list):
            for value in obj:
                found = find_key(value, key)
                if found is not None:
                    return found
        return None


    def aimlab_sens(path):
        if path is None:
            name = "WindowsPlayer_PlayerSettingsData.json"
            cands = glob.glob(os.path.join(AIMLAB_DIR, "Users", "*", name))
            if not cands:
                cands = glob.glob(os.path.join(AIMLAB_DIR, "UserDefault", name))
            if not cands:
                sys.exit("Aim Lab settings not found; pass a sens or --aimlab-file")
            path = max(cands, key=os.path.getmtime)
        try:
            with open(path) as handle:
                data = json.load(handle)
        except (OSError, ValueError) as err:
            sys.exit(f"could not read Aim Lab settings {path}: {err}")
        sens = find_key(data, "mouseSensitivityX")
        if sens is None:
            sys.exit(f"mouseSensitivityX not found in {path}")
        return float(sens), path


    def main():
        p = argparse.ArgumentParser(
            description="Convert mouse sensitivity between games (preserves cm/360).")
        p.add_argument("to_game")
        p.add_argument("from_sens", nargs="?", type=float, default=None,
                       help="source sens (default: read live from Aim Lab)")
        p.add_argument("--from-game", default="valorant",
                       help="source game scale (default valorant)")
        p.add_argument("--from-dpi", type=int, default=1600,
                       help="DPI the source ran at (default 1600 = Aim Lab wrapper)")
        p.add_argument("--base-dpi", type=int, default=1800,
                       help="preferred result DPI; ranking is pulled toward it")
        p.add_argument("--dpi-weight", type=float, default=1.0,
                       help="strength of the --base-dpi pull, in error-%% points "
                            "per 100%% DPI deviation (0 = pure error, higher = closer to base)")
        p.add_argument("--dpi-min", type=int, default=400, help="lowest DPI to search")
        p.add_argument("--dpi-max", type=int, default=3200, help="highest DPI to search")
        p.add_argument("--dpi-step", type=int, default=50, help="DPI search granularity")
        p.add_argument("--aimlab-file", default=None,
                       help="explicit Aim Lab settings JSON path")
        p.add_argument("--top", type=int, default=8, help="rows to show")
        args = p.parse_args()

        for label, val in (("--from-dpi", args.from_dpi), ("--base-dpi", args.base_dpi),
                           ("--dpi-min", args.dpi_min), ("--dpi-step", args.dpi_step)):
            if val <= 0:
                sys.exit(f"{label} must be positive (got {val})")
        if args.dpi_min > args.dpi_max:
            sys.exit(f"--dpi-min ({args.dpi_min}) must be <= --dpi-max ({args.dpi_max})")

        fkey, fg = resolve(args.from_game)
        tkey, tg = resolve(args.to_game)
        step = tg["step"]

        if args.from_sens is None:
            from_sens, src = aimlab_sens(args.aimlab_file)
            note = f" (Aim Lab: {os.path.basename(os.path.dirname(src))})"
        else:
            from_sens, note = args.from_sens, ""
        if from_sens <= 0:
            sys.exit(f"source sens must be positive (got {from_sens:g})")

        target = cm360(fg["yaw"], from_sens, args.from_dpi)

        rows = []
        for dpi in range(args.dpi_min, args.dpi_max + 1, args.dpi_step):
            sens, cm, errpct = best_sens(target, tg, dpi)
            penalty = args.dpi_weight * abs(dpi - args.base_dpi) / args.base_dpi
            rows.append({
                "dpi": dpi, "sens": sens, "cm": cm,
                "errpct": errpct, "edpi": sens * dpi,
                "score": errpct + penalty,
            })

        rows.sort(key=lambda r: (round(r["score"], 6), abs(r["dpi"] - args.base_dpi)))

        base_sens, base_cm, base_err = best_sens(target, tg, args.base_dpi)

        print(f"{CYAN}{BOLD}reference:{RESET} {fkey} sens {BOLD}{from_sens:g}{RESET} "
              f"@ {args.from_dpi} DPI{DIM}{note}{RESET}  ->  {BOLD}{target:.3f}{RESET} cm/360")
        print(f"{CYAN}{BOLD}target:{RESET}    {tkey} "
              f"{DIM}(yaw {tg['yaw']:g}, step {step:g}){RESET}\n")

        bc = err_color(base_err)
        print(f"{CYAN}{BOLD}at base {args.base_dpi} DPI:{RESET}  "
              f"sens {BOLD}{base_sens:g}{RESET}  ->  {base_cm:.3f} cm/360  "
              f"{bc}({base_err:.2f}% off){RESET}\n")

        print(f"{DIM}other DPI options (ranked):{RESET}")
        print(f"{BOLD}  {'DPI':>6}  {'sens':>8}  {'cm/360':>8}  {'error':>9}  {'eDPI':>7}{RESET}")
        print(f"{DIM}  {'-' * 46}{RESET}")
        for r in rows[:args.top]:
            at_base = r["dpi"] == args.base_dpi
            ec = err_color(r["errpct"])
            dpi_cell = f"{CYAN}{BOLD}{r['dpi']:>6}{RESET}" if at_base else f"{r['dpi']:>6}"
            mark = f"  {GREEN}{BOLD}<- @base{RESET}" if at_base else ""
            print(f"  {dpi_cell}  {r['sens']:>8g}  {r['cm']:>8.3f}"
                  f"  {ec}{r['errpct']:>7.2f}%{RESET}  {r['edpi']:>7.0f}{mark}")


    if __name__ == "__main__":
        main()
  '';

  # zsh completion: game names for the positional + --from-game, plus all flags.
  # Game list must stay in sync with GAMES + ALIASES in the script above.
  completion = pkgs.writeTextFile {
    name = "sens-convert-completion";
    destination = "/share/zsh/site-functions/_sens-convert";
    text = ''
      #compdef sens-convert

      local -a games
      games=(overwatch valorant source ow ow2 val cs cs2 csgo apex tf2 quake)

      _arguments -s \
        '(-h --help)'{-h,--help}'[show this help]' \
        '--from-game[source game scale]:game:($games)' \
        '--from-dpi[DPI the source ran at]:dpi:' \
        '--base-dpi[preferred result DPI]:dpi:' \
        '--dpi-weight[strength of the base-dpi pull]:weight:' \
        '--dpi-min[lowest DPI to search]:dpi:' \
        '--dpi-max[highest DPI to search]:dpi:' \
        '--dpi-step[DPI search step]:dpi:' \
        '--aimlab-file[Aim Lab settings JSON]:file:_files' \
        '--top[rows to show]:count:' \
        '1:target game:($games)' \
        '2:source sens (default\: Aim Lab):'
    '';
  };
in {
  home.packages = [
    (pkgs.symlinkJoin {
      name = "sens-convert";
      paths = [sens-convert completion];
    })
  ];
}
