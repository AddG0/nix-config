# Wraps hooks/write-for-people-gate.sh; shared by claude-code.nix and tests/script.nix.
{pkgs}:
pkgs.writeShellApplication {
  name = "documentation-write-for-people-gate";
  runtimeInputs = with pkgs; [jq coreutils gnugrep];
  text = builtins.readFile ./hooks/write-for-people-gate.sh;
}
