# Every discovered test as a check: unit suites through nix-unit in the sandbox, files and script tests as the derivation they return.
{
  inputs,
  self,
  lib,
  ...
}: let
  inherit ((import ./discovery.nix {inherit lib;})) discover withTests;

  tests = discover {
    roots = {
      modules = {
        path = ../modules;
        qualifier = null;
      };
      home = {
        path = ../home;
        qualifier = "home";
      };
      lib = {
        path = ../lib;
        qualifier = "lib";
        flat = true;
      };
      checks = {
        path = ./.;
        qualifier = "checks";
      };
    };
  };

  # Repo-relative, so the runner imports the test from the sandbox's copy of self.
  relative = file: lib.path.removePrefix ../. file;

  byKind = kind: lib.filter (test: test.kind == kind) tests;

  # The arguments a unit suite gets; it sees no flake outputs, so it runs from store paths alone.
  unitArgs = pkgs: let
    harness = import ./harness {
      inherit pkgs;
      inherit (inputs.nixpkgs) lib;
    };
  in {
    inherit harness pkgs;
    inherit (harness) lib;
    inherit (import "${inputs.nix-unit}/lib" {inherit (harness) lib;}) coverage;
  };
in {
  imports = [inputs.nix-unit.modules.flake.testsOutput];

  # `nix-unit --flake .#tests.systems.x86_64-linux` runs every unit suite outside a check.
  flake.tests.systems = lib.genAttrs ["x86_64-linux" "aarch64-darwin"] (system: let
    args = unitArgs inputs.nixpkgs.legacyPackages.${system};
  in
    lib.listToAttrs (map (test: lib.nameValuePair test.name (withTests test (import test.file args))) (byKind "unit")));

  perSystem = {
    pkgs,
    system,
    ...
  }: let
    suiteFile = test:
      pkgs.writeText "${lib.replaceStrings [":"] ["-"] test.name}.nix" ''
        let
          lib = import ${inputs.nixpkgs}/lib;
          pkgs = import ${inputs.nixpkgs} {system = "${system}";};
          harness = import ${self}/checks/harness {inherit pkgs lib;};
        in
          import ${self}/${relative test.file} {
            inherit harness pkgs;
            inherit (harness) lib;
            inherit (import ${inputs.nix-unit}/lib {inherit (harness) lib;}) coverage;
          }
      '';

    unitCheck = test:
      builtins.seq (withTests test (import test.file (unitArgs pkgs))) (pkgs.runCommand (lib.replaceStrings [":"] ["-"] test.name) {nativeBuildInputs = [inputs.nix-unit.packages.${system}.nix-unit];} ''
        export HOME="$(realpath .)"
        unset NIX_STORE
        export NIX_STORE_DIR=${builtins.storeDir}
        export NIX_REMOTE="$HOME/storedata"
        nix-unit --show-trace ${suiteFile test} 2>&1 | tee "$out"
        test "''${PIPESTATUS[0]}" -eq 0
      '');

    harness = import ./harness {inherit pkgs lib;};
    derivationCheck = test:
      import test.file {
        inherit pkgs harness self;
        inherit (harness) lib;
      };
  in {
    checks = lib.listToAttrs (map (test:
      lib.nameValuePair test.name (
        if test.kind == "unit"
        then unitCheck test
        else derivationCheck test
      ))
    tests);
  };
}
