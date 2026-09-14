{pkgs}:
pkgs.writeShellApplication {
  name = "codex-config-merge";
  runtimeInputs = [pkgs.yj pkgs.jq];
  text = ''
    if [ "$#" -ne 2 ]; then
      echo "usage: codex-config-merge <declared.toml> <target.toml>" >&2
      exit 1
    fi
    declared=$1
    target=$2

    # Still a link means Codex has not written anything back yet.
    runtime='{}'
    if [ -f "$target" ] && [ ! -L "$target" ] && ! runtime=$(yj -tj <"$target" 2>/dev/null); then
      echo "codex-config-merge: $target is not valid TOML. Refusing to overwrite it --" \
           "it may hold project trust worth keeping. Fix or delete it, then re-run activation." >&2
      exit 1
    fi

    directory=$(dirname "$target")
    mkdir -p "$directory"
    staged=$(mktemp "$directory/.config.toml.XXXXXX")
    trap 'rm -f "$staged"' EXIT

    # jq's `*` merges recursively with the right side winning, so declared beats runtime.
    yj -tj <"$declared" | jq --argjson runtime "$runtime" '$runtime * .' | yj -jt >"$staged"
    # Codex has to be able to write it back; the store link was 0444.
    chmod 600 "$staged"
    mv -f "$staged" "$target"
  '';
  meta.description = "Merge Codex's runtime config.toml over the Nix-declared one";
}
