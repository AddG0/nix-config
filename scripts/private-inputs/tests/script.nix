# just private-inputs: which repos it reports a host's build fetching over SSH, against a nix that plays back a debug log.
{
  harness,
  pkgs,
  self,
  ...
}: let
  # Plays back a host's eval through its debug log.
  nix = pkgs.writeShellScriptBin "nix" ''
    echo "$1 $2 $3 $4" >"$OUT/nix-args"
    printf '%s' "''${FAKE_DEBUG_LOG:-}" >&2
    exit "''${FAKE_EVAL_EXIT:-0}"
  '';
in
  harness.bats "private-inputs" [./private-inputs.bats] {
    nativeBuildInputs = [nix];
    privateInputs = "${self}/scripts/private-inputs/private-inputs.sh";
  }
