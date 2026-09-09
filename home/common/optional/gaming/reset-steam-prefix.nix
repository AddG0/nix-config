# reset-steam-prefix: move a game's Proton prefix aside so Steam rebuilds it on
# next launch. For a prefix whose symlinks point at a Proton that is gone.
#
#   reset-steam-prefix 'R.E.P.O.'
{pkgs, ...}: let
  reset-steam-prefix = pkgs.writeShellApplication {
    name = "reset-steam-prefix";
    runtimeInputs = with pkgs; [coreutils gnused];
    text = ''
      steamapps="$HOME/.local/share/Steam/steamapps"
      [ $# -eq 1 ] || {
        echo "usage: reset-steam-prefix <game name>" >&2
        exit 1
      }

      shopt -s nullglob
      for f in "$steamapps"/appmanifest_*.acf; do
        [ "$(sed -n 's/.*"name"[[:space:]]*"\(.*\)".*/\1/p' "$f" | head -1)" = "$1" ] || continue
        id=''${f##*appmanifest_}
        prefix="$steamapps/compatdata/''${id%.acf}"
        [ -d "$prefix" ] || {
          echo "$1 has no prefix" >&2
          exit 1
        }
        dest="$prefix.bak-$(date +%Y%m%d-%H%M%S)"
        # -T so a same-second repeat errors instead of nesting one inside the other.
        mv -T "$prefix" "$dest"
        echo "moved to $dest; Steam rebuilds the prefix on next launch"
        exit 0
      done

      echo "no installed game named: $1" >&2
      exit 1
    '';
  };

  # Names are read at completion time, not baked in: the installed set changes.
  completion = pkgs.writeTextFile {
    name = "reset-steam-prefix-completion";
    destination = "/share/zsh/site-functions/_reset-steam-prefix";
    text = ''
      #compdef reset-steam-prefix

      _reset_steam_prefix_games() {
        local -a games
        local f id steamapps=$HOME/.local/share/Steam/steamapps
        for f in $steamapps/appmanifest_*.acf(N); do
          id=''${f##*appmanifest_}
          [[ -d $steamapps/compatdata/''${id%.acf} ]] || continue
          games+=("$(sed -n 's/.*"name"[[:space:]]*"\(.*\)".*/\1/p' $f | head -1)")
        done
        compadd -a games
      }

      _arguments '1:game:_reset_steam_prefix_games'
    '';
  };
in {
  home.packages = [
    (pkgs.symlinkJoin {
      name = "reset-steam-prefix";
      paths = [reset-steam-prefix completion];
    })
  ];
}
