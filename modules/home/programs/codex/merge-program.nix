{pkgs}: let
  python = pkgs.python3.withPackages (ps: [ps.tomli-w]);
in
  pkgs.writeShellApplication {
    name = "codex-config-merge";
    runtimeInputs = [python];
    text = ''
      exec python3 ${./config-merge.py} "$@"
    '';
    meta.description = "Merge Codex's runtime config.toml over the Nix-declared one";
  }
