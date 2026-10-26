# Codex's own validators: strict `mcp list` loads of config.toml, each profile and hooks.json, and `doctor`'s config.load row.
{
  config,
  lib,
  pkgs,
  codexHome,
}: let
  codex = config.programs.codex;
in {
  option = "programs.codex";
  inherit (codex) enable package;
  configDirs = [codexHome];
  # Codex reads skills from ~/.agents/skills.
  extraDirs = [".agents"];
  mergedFiles = lib.optionals codex.writableConfig (map (file: "${codexHome}/${file}") (["config.toml"] ++ map (profile: "${profile}.config.toml") (lib.attrNames codex.profiles)));

  setup = ''
    export PATH=${lib.makeBinPath [pkgs.jq pkgs.jaq]}:$PATH

    # Doctor exits 1 offline (no auth, no network), so only its config.load row decides; malformed agent roles land there.
    codex_startup() {
      local out problems status=0
      echo "$subject: codex: $2: codex doctor" >>"$ran"
      out=$(timeout "$limit" "$1" doctor --json 2>"$TMPDIR/doctor.err" </dev/null) || status=$?
      if [[ $status -eq 124 ]]; then
        report codex "$2" "codex doctor --json" "timed out after $limit s"$'\n'"$(cat "$TMPDIR/doctor.err")"
        return
      fi
      if ! jq -e '.checks["config.load"]' <<<"$out" >/dev/null 2>&1; then
        report codex "$2" "codex doctor --json" "exit $status, and its report has no config.load check:"$'\n'"$out"$'\n'"$(cat "$TMPDIR/doctor.err")"
        return
      fi
      problems=$(jq -r -f ${./config-load.jq} <<<"$out")
      if [[ -n $problems ]]; then
        report codex "$2" "codex doctor --json" "$problems"
      fi
    }

    # Codex reads hooks.json only when a session starts; [hooks] in config.toml is the same type and `mcp list` loads it strictly.
    codex_hooks() {
      local scratch="$TMPDIR/codex-hooks" hooks="$CODEX_HOME/hooks.json"
      if ! jq -e 'type == "object" and (keys - ["description", "hooks"]) == [] and ((.hooks // {}) | type == "object")' "$hooks" >/dev/null 2>&1; then
        report codex "$2/hooks.json" "jq" "hooks.json must be a JSON object with only \`description\` and an object \`hooks\`:"$'\n'"$(cat "$hooks")"
        return
      fi
      rm -rf "$scratch"
      cp -r "$CODEX_HOME" "$scratch"
      rm "$scratch/hooks.json"
      if [[ ! -f $scratch/config.toml ]]; then
        echo '{}' >"$TMPDIR/config.json"
      elif ! jaq --from toml . "$scratch/config.toml" >"$TMPDIR/config.json" 2>"$TMPDIR/hooks.err"; then
        report codex "$2/config.toml" "jaq --from toml" "$(cat "$TMPDIR/hooks.err")"
        return
      fi
      # JSON null means "unset" to Codex, but TOML cannot hold one.
      if ! { jq -s '.[0] * {hooks: (.[1].hooks // {} | walk(if type == "object" then with_entries(select(.value != null)) else . end))}' "$TMPDIR/config.json" "$hooks" | jaq --to toml . >"$scratch/config.toml"; } 2>"$TMPDIR/hooks.err"; then
        report codex "$2/hooks.json" "jq | jaq --to toml" "$(cat "$TMPDIR/hooks.err")"
        return
      fi
      CODEX_HOME="$scratch"
      validate codex "$2/hooks.json" "$1" mcp list
      CODEX_HOME="$HOME/$2"
    }
  '';

  script = package: let
    codexBin = "${package}/bin/codex";
  in ''
    export CODEX_HOME="$HOME/"${lib.escapeShellArg codexHome}
    validate codex ${lib.escapeShellArg "${codexHome}/config.toml"} ${codexBin} mcp list
    for profile in ${lib.escapeShellArgs (lib.attrNames codex.profiles)}; do
      validate codex "${codexHome}/$profile.config.toml" ${codexBin} --profile "$profile" mcp list
    done
    codex_startup ${codexBin} ${lib.escapeShellArg codexHome}
    if [[ -f $CODEX_HOME/hooks.json ]]; then
      codex_hooks ${codexBin} ${lib.escapeShellArg codexHome}
    fi
    unset CODEX_HOME
  '';
}
