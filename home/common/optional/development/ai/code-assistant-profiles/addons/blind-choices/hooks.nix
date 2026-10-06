# Wraps hooks/<name>.sh; shared by claude-code.nix and tests.nix.
{pkgs}: name:
pkgs.writeShellApplication {
  name = "blind-choices-${name}";
  runtimeInputs = with pkgs; [jq coreutils];
  text = builtins.readFile ./hooks/${name}.sh;
}
