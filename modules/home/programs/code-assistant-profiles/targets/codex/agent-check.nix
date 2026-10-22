# Codex's own load of an agent role, run while its TOML builds: `codex doctor`'s config.load row names a role Codex cannot read.
{
  lib,
  pkgs,
}: {
  enable,
  package,
}: name: file: let
  doctorTimeoutSeconds = 60;
in
  if !enable
  then file
  else if package == null
  then throw "codex agent ${name}: programs.code-assistant-profiles.targets.codex.checkConfig is on but programs.codex.package is null, so Codex cannot load agents/${name}.toml while it builds; set programs.codex.package, or checkConfig = false to write roles unchecked"
  else
    pkgs.runCommand "codex-agent-${lib.strings.sanitizeDerivationName name}.toml" {nativeBuildInputs = [pkgs.jq];} ''
      export HOME=$TMPDIR CODEX_HOME=$TMPDIR/codex
      mkdir -p "$CODEX_HOME/agents"
      cp ${file} "$CODEX_HOME/agents/${name}.toml"
      # Doctor exits 1 offline (no auth, no network), so only its config.load row decides.
      report=$(timeout ${toString doctorTimeoutSeconds} ${lib.getExe' package "codex"} doctor --json 2>doctor.err </dev/null) || true
      if ! jq -e '.checks["config.load"]' <<<"$report" >/dev/null 2>&1; then
        echo "codex agent ${name}: \`codex doctor --json\` reported no config.load check:" >&2
        echo "$report" >&2
        cat doctor.err >&2
        exit 1
      fi
      problems=$(jq -r -f ${./config-load.jq} <<<"$report")
      if [[ -n $problems ]]; then
        echo "codex agent ${name}: \`codex doctor --json\` rejected agents/${name}.toml:" >&2
        echo "$problems" >&2
        exit 1
      fi
      cp ${file} "$out"
    ''
