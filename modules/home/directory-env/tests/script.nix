{
  harness,
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
      ../default.nix
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
in
  harness.bats "directory-env-test" [./directory-env.bats] {
    inherit runner wrappedEnv tree;
  }
