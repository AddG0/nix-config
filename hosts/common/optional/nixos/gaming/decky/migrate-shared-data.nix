# `decky-migrate-shared-data <state-dir> <data-dir>`: moves plugin data from the old shared dir into the boot user's.
{pkgs}:
pkgs.writeShellApplication {
  name = "decky-migrate-shared-data";
  runtimeInputs = [pkgs.coreutils pkgs.findutils];
  text = ''
    state=$1
    data=$2
    if [[ ! -d $data ]]; then
      echo "decky: $data is missing, so plugin data stays in $state" >&2
      exit 0
    fi
    failed=0
    for sub in data settings logs themes; do
      [[ -d $state/$sub ]] || continue
      while IFS= read -r -d "" entry; do
        target="$data/$sub/$(basename "$entry")"
        if [[ -e $target || -L $target ]]; then
          echo "decky: $target already exists, leaving $entry in place" >&2
          continue
        fi
        # Owner first, so an interrupted move never leaves a root-owned entry the next run skips.
        if mkdir -p "$data/$sub" && chown --reference="$data" "$data/$sub" \
          && chown -hR --reference="$data" "$entry" && mv "$entry" "$target"; then
          echo "decky: moved $entry to $target"
        else
          echo "decky: could not move $entry to $target" >&2
          failed=1
        fi
      done < <(find "$state/$sub" -mindepth 1 -maxdepth 1 ! -name loader.json -print0)
      # settings/ keeps loader.json, which stays shared.
      [[ $sub == settings ]] || rmdir --ignore-fail-on-non-empty "$state/$sub" || failed=1
    done
    exit "$failed"
  '';
}
