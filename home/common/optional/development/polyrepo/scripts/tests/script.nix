# Worktree reconcile in the real ghq-gitlab-group.sh, against a stub ghq and glab.
{
  harness,
  pkgs,
  ...
}: let
  # root -> $TEST_GHQ_ROOT; get succeeds without cloning.
  ghq = pkgs.writeShellScriptBin "ghq" ''
    case "''${1:-}" in
      root) printf '%s\n' "$TEST_GHQ_ROOT" ;;
      get) exit 0 ;;
      *) echo "ghq stub: unexpected $*" >&2; exit 1 ;;
    esac
  '';
  # Logs every call to $TEST_GLAB_LOG; the group lists primary-repo only, and every other path is a 404.
  glab = pkgs.writeShellScriptBin "glab" ''
    printf '%s\n' "$*" >>"$TEST_GLAB_LOG"
    case "$1 ''${2:-}" in
      "auth status") exit 0 ;;
      "api --paginate") printf '%s\n' '[{"path_with_namespace":"my-org/team/primary-repo"}]' ;;
      "api projects/"*) printf '%s\n' '404 Project Not Found (HTTP 404)' >&2; exit 1 ;;
      *) echo "glab stub: unexpected $*" >&2; exit 1 ;;
    esac
  '';
in
  harness.bats "polyrepo-scripts-script" [./ghq-gitlab-group.bats] {
    nativeBuildInputs = [ghq glab pkgs.jq pkgs.git];
    script = ../ghq-gitlab-group.sh;
  }
