# Claude Code's own validators over a whole profile: `plugin validate` on each profile dir, `doctor` on settings.json; plugin dirs validate as they build.
{
  config,
  lib,
}: let
  claude = config.programs.claude-code-profiles;
  profileDirs = lib.optionals claude.enable (lib.mapAttrsToList (_: profile: profile.profileDir) claude.profiles);
in {
  option = "programs.claude-code-profiles";
  inherit (claude) enable package;
  configDirs = profileDirs;

  setup = ''
    export DISABLE_AUTOUPDATER=1
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

    # Detection rests on doctor's wording, so this claude must still file a known-bad settings.json under it.
    claude_canary() {
      local dir="$TMPDIR/claude-canary" out
      mkdir -p "$dir"
      echo '{"permissions": {"defaultMode": "bogus"}}' >"$dir/settings.json"
      echo "$subject: claude-code: canary settings.json: claude doctor" >>"$ran"
      out=$(CLAUDE_CONFIG_DIR="$dir" timeout "$limit" "$1" doctor 2>&1 </dev/null | plain) || true
      if ! grep -q '^Invalid settings' <<<"$out"; then
        report claude-code "canary settings.json" "claude doctor" "permissions.defaultMode = \"bogus\" is not listed under 'Invalid settings', so this claude's doctor output can no longer be read:"$'\n'"$out"
      fi
    }

    # `claude doctor` is Claude Code's only offline settings check; it lists bad settings but still exits 0.
    claude_settings() {
      local out status=0
      echo "$subject: claude-code: $2/settings.json: claude doctor" >>"$ran"
      out=$(CLAUDE_CONFIG_DIR="$HOME/$2" timeout "$limit" "$1" doctor 2>&1 </dev/null | plain) || status=$?
      if [[ $status -ne 0 ]]; then
        report claude-code "$2/settings.json" "claude doctor" "exit $status"$'\n'"$out"
      elif ! grep -q '^Claude Code doctor' <<<"$out"; then
        report claude-code "$2/settings.json" "claude doctor" "its report lacks the 'Claude Code doctor' heading, so its settings check cannot be read:"$'\n'"$out"
      elif grep -q '^Invalid settings' <<<"$out"; then
        report claude-code "$2/settings.json" "claude doctor" "$(sed -n '/^Invalid settings/,/^[^-[:space:]]/{/^Invalid settings/p;/^[-[:space:]]/p}' <<<"$out")"
      fi
    }
  '';

  script = package: let
    claudeBin = "${package}/bin/claude";
  in ''
    claude_canary ${claudeBin}
    for dir in ${lib.escapeShellArgs profileDirs}; do
      validate claude-code "$dir" ${claudeBin} plugin validate "$HOME/$dir"
      if [[ -f $HOME/$dir/settings.json ]]; then
        claude_settings ${claudeBin} "$dir"
      fi
    done
  '';
}
