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

    exec ${pkgs.rsync}/bin/rsync -av \
      --exclude='.git' \
      --filter=':- .gitignore' \
      "$@"
  '';
in {
  home.packages = [gsync];
}
