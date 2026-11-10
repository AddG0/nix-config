# The self-documenting gate's two hooks, each built from state.sh plus its own script; used by ../claude-code.nix and tests/script.nix.
{pkgs}: let
  hook = name: parts:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [jq git gawk gnugrep gnused coreutils ast-grep];
      text = pkgs.lib.concatMapStrings builtins.readFile ([./state.sh] ++ parts);
    };
in {
  baseline = hook "self-documenting-baseline" [./baseline.sh];
  gate = hook "self-documenting-gate" [
    (pkgs.writeText "sgconfig.sh" "sgconfig=${./ast-grep}/sgconfig.yml\n")
    ./findings.sh
    ./gate.sh
  ];
}
