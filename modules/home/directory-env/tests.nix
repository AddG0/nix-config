# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  # A store path, so the tree the rule names exists inside the build sandbox.
  tree = pkgs.runCommand "directory-env-test-tree" {} ''
    mkdir -p $out/scoped/deep $out/scoped-sibling
  '';

  eval = lib.evalModules {
    specialArgs = {inherit pkgs;};
    modules = [
      ./default.nix
      # Stands in for home-manager's zsh module, which isn't in scope here.
      {options.programs.zsh.initContent = lib.mkOption {type = lib.types.lines;};}
      {
        programs.directoryEnv.rules = [
          {
            paths = ["${tree}/scoped"];
            env.DIRECTORY_ENV_TEST = "applied";
          }
        ];
      }
    ];
  };

  runner = lib.getExe eval.config.programs.directoryEnv.runner;
  wrappedEnv = lib.getExe' (eval.config.programs.directoryEnv.wrap "${pkgs.coreutils}/bin/env") "env";

  # printenv exits 1 on an unset name, which would kill `set -e` mid-assert.
  readVar = "${runner} sh -c 'printf %s \"\${DIRECTORY_ENV_TEST-}\"'";
in
  pkgs.runCommand "directory-env-test" {} ''
    set -euo pipefail

    expect() {
      local where="$1" want="$2" got
      got="$(cd "$where" && ${readVar})"
      if [ "$got" != "$want" ]; then
        echo "in $where: expected DIRECTORY_ENV_TEST='$want', got '$got'" >&2
        exit 1
      fi
    }

    echo "exports the rule's env at the named path"
    expect ${tree}/scoped applied

    echo "exports it below the named path"
    expect ${tree}/scoped/deep applied

    echo "leaves it unset in a sibling sharing the path as a prefix"
    expect ${tree}/scoped-sibling ""

    echo "leaves it unset outside the tree"
    expect ${tree} ""

    echo "forwards argv to the command it execs"
    got="$(${runner} printf '%s|%s' one two)"
    [ "$got" = "one|two" ] || { echo "expected 'one|two', got '$got'" >&2; exit 1; }

    echo "wrap keeps the wrapped program's name and applies the rules"
    case "${wrappedEnv}" in */bin/env) ;; *) echo "wrap renamed env to ${wrappedEnv}" >&2; exit 1 ;; esac
    got="$(cd ${tree}/scoped && ${wrappedEnv} | grep '^DIRECTORY_ENV_TEST=')"
    [ "$got" = "DIRECTORY_ENV_TEST=applied" ] || { echo "wrap: got '$got'" >&2; exit 1; }

    touch $out
  ''
