{pkgs, ...}: let
  scratch = pkgs.writeShellApplication {
    name = "scratch";
    runtimeInputs = with pkgs; [git coreutils];
    text = ''
      # Live under ghq's root so scratches show up in `ghq list` and the
      # Alt-G fuzzy picker. The `scratch/` segment plays the part of a
      # sentinel "host" — ghq list will display `scratch/<name>`.
      root="$HOME/Projects/code/scratch"

      if [[ "''${1:-}" == "-l" ]]; then
        [[ -d "$root" ]] || { echo "no scratches yet" >&2; exit 0; }
        ls -1 "$root"
        exit 0
      fi

      name="''${1:-}"
      if [[ -z "$name" ]]; then
        echo "usage: scratch <name>   |   scratch -l" >&2
        exit 2
      fi

      dir="$root/$name"
      if [[ -e "$dir" ]]; then
        echo "scratch: $dir already exists" >&2
        exit 1
      fi

      mkdir -p "$dir"
      git -C "$dir" init -q
      # Print path on stdout so the shell wrapper can cd into it.
      printf '%s\n' "$dir"
    '';
  };
in {
  home.packages = [scratch];

  # Wrapper so `scratch foo` also cds the calling shell into the new dir.
  # The package does the real work (mkdir + git init) and prints the path;
  # this function just captures stdout and cds. -l (list) passes through.
  programs.zsh.initContent = ''
    scratch() {
      if [[ -z "$1" || "$1" == "-l" ]]; then
        command scratch "$@"
        return
      fi
      local dir
      dir=$(command scratch "$@") || return
      cd "$dir"
    }
  '';
}
