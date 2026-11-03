# A `tmuxinator` for sesh's PATH: answers sesh's `list -n` without starting Ruby, hands everything else to the real one.
{
  lib,
  writeShellApplication,
  coreutils,
  findutils,
  gnused,
  tmuxinator,
}:
writeShellApplication {
  name = "tmuxinator";
  runtimeInputs = [coreutils findutils gnused];
  text = ''
    if [ "$*" != "list -n" ]; then
      exec ${lib.getExe tmuxinator} "$@"
    fi

    # tmuxinator's Config.directories: $TMUXINATOR_CONFIG alone, else the XDG dir then ~/.tmuxinator.
    if [ -n "''${TMUXINATOR_CONFIG:-}" ]; then
      dirs=("$TMUXINATOR_CONFIG")
    else
      dirs=("''${XDG_CONFIG_HOME:-$HOME/.config}/tmuxinator" "$HOME/.tmuxinator")
    fi

    names=$(
      for dir in "''${dirs[@]}"; do
        if [ -d "$dir" ]; then
          # Ruby's Dir["**/*.yml"] skips dotfiles and dot-dirs; the name keeps any subfolder.
          # An unreadable subfolder is reported but, as in Ruby's Dir[], does not drop the rest.
          { find "$dir" -mindepth 1 -name '.*' -prune -o -name '*.yml' -printf '%P\n' || true; } | sed 's/\.yml//g'
        fi
      done | LC_ALL=C sort
    )
    echo "tmuxinator projects:"
    # One block like tmuxinator's `say names.join("\n")`, so no projects still prints an empty line.
    printf '%s\n' "$names"
  '';
}
