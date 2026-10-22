# The one way tests evaluate our modules: Home Manager stubs, lib.custom and pkgs injected, plus assertions on rendered files.
{
  pkgs,
  lib,
}: let
  # `nix flake check` and the unit runner hand over a plain nixpkgs lib; the module tree reads lib.custom.
  libWithCustom =
    if lib ? custom
    then lib
    else lib.extend (final: _: {custom = import ../../lib {lib = final;};});

  stubs = import ./stubs.nix {inherit pkgs;};

  # One of our modules, which take customLib through importApply.
  module = path: lib.modules.importApply path {customLib = libWithCustom.custom;};

  evaluate = modules:
    lib.evalModules {
      class = "homeManager";
      # specialArg: _module.args.lib lands too late for the imported modules' own `lib`.
      specialArgs.lib = libWithCustom;
      modules =
        [
          stubs.home
          {
            _module.args = {
              inherit pkgs;
              customLib = libWithCustom.custom;
            };
          }
        ]
        ++ modules;
    };

  # A home.file entry as the store path Home Manager would link.
  fileSource = name: entry: entry.source or (pkgs.writeText (baseNameOf name) entry.text);

  # nmt-style shell assertions over files `pathOf` resolves by name; each names the behaviour it checks.
  assertFiles = pathOf: let
    fail = label: detail: ''echo "FAIL ${label}: "${lib.escapeShellArg detail} >&2; exit 1'';
    needleCheck = label: name: op: verb: needles:
      ''
        content=$(cat ${pathOf name}; echo x)
        content=''${content%x}
      ''
      + lib.concatMapStrings (needle: ''
        [[ $content ${op} *${lib.escapeShellArg needle}* ]] || { ${fail label "${name} ${verb} ${needle}"}; }
      '')
      needles;
  in {
    path = pathOf;
    exists = label: name: ''
      test -e ${pathOf name} || { ${fail label "${name} is not rendered"}; }
    '';
    missing = label: name: ''
      test ! -e ${pathOf name} || { ${fail label "${name} is rendered"}; }
    '';
    # Trailing newlines aside, as `$(cat)` reads them.
    content = label: name: expected: ''
      diff -u <(printf '%s\n' "$(cat ${pkgs.writeText "expected-${baseNameOf name}" expected})") <(printf '%s\n' "$(cat ${pathOf name})") >&2 || { ${fail label "${name} differs from the expected content above"}; }
    '';
    contains = label: name: needles: needleCheck label name "==" "lacks" needles;
    lacks = label: name: needles: needleCheck label name "!=" "has" needles;
    jq = label: name: filter: ''
      ${pkgs.jq}/bin/jq -e ${lib.escapeShellArg filter} ${pathOf name} >/dev/null || { cat ${pathOf name} >&2; ${fail label "${name} does not satisfy jq ${filter}"}; }
    '';
    # Compared as JSON so the check does not hinge on the TOML writer's layout.
    toml = label: name: expected: ''
      actual=$(${pkgs.python3.interpreter} -c 'import json, sys, tomllib; print(json.dumps(tomllib.load(open(sys.argv[1], "rb")), sort_keys=True, separators=(",", ":")))' ${pathOf name})
      test "$actual" = ${lib.escapeShellArg (builtins.toJSON expected)} || { echo "got $actual" >&2; ${fail label "${name}: expected ${builtins.toJSON expected}"}; }
    '';
  };

  files = homeFiles:
    assertFiles (name:
      lib.throwIfNot (homeFiles ? ${name}) "harness: no home.file entry ${name}; have ${lib.concatStringsSep ", " (lib.attrNames homeFiles)}"
      (fileSource name homeFiles.${name}));

  # Store paths named by themselves, for a render's own outputs.
  paths = assertFiles lib.id;

  # nix-unit-shaped cases checked at evaluation, for a files: test whose values need the flake; a failure prints both sides.
  values = cases: let
    failures = lib.runTests cases;
  in
    lib.optionalString (failures != []) ''
      cat >&2 <<'HARNESS_FAILURES'
      ${lib.concatMapStringsSep "
" (f: "FAIL ${lib.removePrefix "test " f.name}:
  expected ${lib.generators.toPretty {} f.expected}
  got      ${lib.generators.toPretty {} f.result}") failures}
      HARNESS_FAILURES
      exit 1
    '';

  # A files: or script: check: the script runs in a sandbox, and the check passes when it exits 0.
  check = name: script:
    pkgs.runCommand name {} ''
      ${script}
      touch "$out"
    '';
in {
  lib = libWithCustom;
  # The repo, for a test reaching a module outside its own tree.
  root = ../..;
  inherit stubs module evaluate files paths values check;
  eval = modules: (evaluate modules).config;
}
