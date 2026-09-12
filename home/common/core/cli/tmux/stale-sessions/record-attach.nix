# The state directory and key encoding must match ./prune.nix; ./tests.nix
# round-trips the two to catch drift.
{
  writeShellApplication,
  coreutils,
}:
writeShellApplication {
  name = "tmux-record-session-attach";
  runtimeInputs = [coreutils];
  text = ''
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tmux/last-attached"
    install -d -m 700 "$state_dir"
    # base64url: the standard alphabet emits "/", which would split the path.
    key=$(printf '%s' "$1" | basenc --base64url -w 0)
    printf '%s\n' "$EPOCHSECONDS" > "$state_dir/$key"
  '';
}
