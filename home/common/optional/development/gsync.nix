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

    # Collect .gitignore files from parent directories (backward pass)
    collect_parent_gitignores() {
      local dir="$1"
      local excludes=()
      dir="$(cd "$dir" 2>/dev/null && pwd)"
      while [ "$dir" != "/" ]; do
        if [ -f "$dir/.gitignore" ]; then
          excludes=("--exclude-from=$dir/.gitignore" "''${excludes[@]}")
        fi
        dir="$(dirname "$dir")"
      done
      echo "''${excludes[@]}"
    }

    # Resolve source directory (last non-option arg before dest)
    SOURCE_DIR=""
    for arg in "$@"; do
      case "$arg" in
        -*) ;;
        *)  SOURCE_DIR="$arg" ;;
      esac
    done

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
        --filter=':- .gitignore' \
        "$@"
    fi

    # Fallback: not in a git repo, walk parent dirs + forward filter
    PARENT_EXCLUDES=""
    if [ -n "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ]; then
      PARENT_EXCLUDES="$(collect_parent_gitignores "$SOURCE_DIR")"
    fi

    # shellcheck disable=SC2086
    exec ${pkgs.rsync}/bin/rsync -av \
      --exclude='.git' \
      $PARENT_EXCLUDES \
      --filter=':- .gitignore' \
      "$@"
  '';
in {
  home.packages = [gsync];
}
