{pkgs, ...}: let
  gsync = pkgs.writeShellScriptBin "gsync" ''
    # gsync - git-aware rsync that respects .gitignore and excludes .git
    # Usage: gsync [rsync-options] source/ destination/

    if [ $# -lt 2 ]; then
      echo "Usage: gsync [options] source/ destination/"
      echo ""
      echo "Git-aware rsync that:"
      echo "  - Excludes .git directories"
      echo "  - Respects .gitignore files"
      echo ""
      echo "Examples:"
      echo "  gsync ./project/ /backup/project/"
      echo "  gsync -n ./project/ user@server:/path/  # dry-run"
      echo "  gsync --delete ./src/ ./dest/           # mirror with delete"
      exit 1
    fi

    # If in a git repo, use git's own ignore logic to build an exclude list
    REPO_ROOT="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null)"
    if [ -n "$REPO_ROOT" ]; then
      EXCLUDE_FILE="$(mktemp)"
      trap "rm -f $EXCLUDE_FILE" EXIT
      ${pkgs.git}/bin/git ls-files -oi --exclude-standard --directory \
        | sed 's|/$||' > "$EXCLUDE_FILE"
      exec ${pkgs.rsync}/bin/rsync -av \
        --exclude='.git' \
        --exclude-from="$EXCLUDE_FILE" \
        "$@"
    fi

    # Fallback: not in a git repo, use .gitignore files if present
    exec ${pkgs.rsync}/bin/rsync -av \
      --exclude='.git' \
      --filter=':- .gitignore' \
      "$@"
  '';
in {
  home.packages = [gsync];
}
