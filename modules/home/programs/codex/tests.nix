# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  merge = lib.getExe (import ./merge-program.nix {inherit pkgs;});

  declared = (pkgs.formats.toml {}).generate "declared.toml" {
    check_for_update_on_startup = false;
    tui = {
      theme = "catppuccin-mocha";
      status_line = ["git-branch"];
    };
    mcp_servers.demo.command = "/bin/demo";
  };

  # What Codex itself writes once a directory is trusted.
  runtimeState = pkgs.writeText "runtime.toml" ''
    check_for_update_on_startup = true

    [tui]
    theme = "a-theme-codex-picked"

    [projects."/home/someone/repo"]
    trust_level = "trusted"

    [tui.model_availability_nux]
    "gpt-5.5" = 4
  '';

  # perSystem gets a plain nixpkgs lib; the module reaches for hm.dag.
  hmLib =
    if lib ? hm
    then lib
    else
      lib.extend (_: _: {
        hm.dag.entryAfter = after: data: {
          inherit after data;
          before = [];
        };
      });

  # Only what the module reads, so the check does not drag in home-manager.
  hostStub = {lib, ...}: {
    options = {
      home.homeDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/home/t";
      };
      home.preferXdgDirectories = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      home.activation = lib.mkOption {
        type = lib.types.attrsOf lib.types.unspecified;
        default = {};
      };
      home.file = lib.mkOption {
        default = {};
        type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
            force = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            target = lib.mkOption {
              type = lib.types.str;
              default = name;
            };
            source = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
          };
        }));
      };
      xdg.configHome = lib.mkOption {
        type = lib.types.str;
        default = "/home/t/.config";
      };
      programs.codex.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      programs.codex.settings = lib.mkOption {
        type = lib.types.nullOr lib.types.attrs;
        default = {};
      };
    };
  };

  configured =
    (lib.evalModules {
      specialArgs.lib = hmLib;
      modules = [
        hostStub
        ./default.nix
        {
          _module.args = {inherit pkgs;};
          programs.codex = {
            enable = true;
            settings.model = "some-model";
            mutableConfig.enable = true;
          };
          # Stands in for the entry upstream's programs.codex writes.
          home.file."/.config/codex/config.toml".source = declared;
        }
      ];
    })
    .config;

  managedEntry = configured.home.file."/.config/codex/config.toml";

  expect = label: actual: expected:
    lib.optionalString (actual != expected) ''
      echo "FAIL ${label}: expected ${lib.generators.toPretty {} expected}, got ${lib.generators.toPretty {} actual}" >&2
      exit 1
    '';

  reader = pkgs.writers.writePython3 "read-toml" {} ''
    import sys
    import tomllib

    with open(sys.argv[1], "rb") as handle:
        data = tomllib.load(handle)
    # "|" separates key segments: TOML keys contain both dots and slashes.
    for path in sys.argv[2:]:
        cursor = data
        for part in path.split("|"):
            cursor = cursor[part]
        print(f"{path}={cursor}")
  '';
in
  pkgs.runCommand "codex-mutable-config-test" {} ''
    ${expect "config.toml is handed over, not managed" managedEntry.enable false}
    ${expect "force is not relied on — linkGeneration backs up a real file regardless" managedEntry.force false}
    ${expect "the merge still runs at activation" (configured.home.activation ? codexMutableConfig) true}
    ${expect "activation waits for linkGeneration to finish cleaning up" configured.home.activation.codexMutableConfig.after ["linkGeneration"]}

    fail() {
      echo "FAIL: $1" >&2
      shift
      for f in "$@"; do
        echo "--- $f" >&2
        cat "$f" >&2
      done
      exit 1
    }

    mkdir -p linkcase
    ln -s ${declared} linkcase/config.toml
    ${merge} ${declared} "$PWD/linkcase/config.toml"

    [ -L linkcase/config.toml ] && fail "the store link survived the merge"
    [ -w linkcase/config.toml ] || fail "the merged config is not writable"
    [ "$(stat -c%a linkcase/config.toml)" = "600" ] ||
      fail "expected mode 600, got $(stat -c%a linkcase/config.toml)"

    # --- what Codex wrote survives a rebuild, declared settings still win ---
    cp ${runtimeState} statecase.toml
    chmod +w statecase.toml
    ${merge} ${declared} "$PWD/statecase.toml"

    ${reader} statecase.toml \
      'projects|/home/someone/repo|trust_level' \
      'tui|model_availability_nux|gpt-5.5' \
      'tui|theme' \
      'tui|status_line' \
      'check_for_update_on_startup' \
      'mcp_servers|demo|command' >merged.txt

    grep -qxF 'projects|/home/someone/repo|trust_level=trusted' merged.txt ||
      fail "project trust was dropped" merged.txt
    grep -qxF 'tui|model_availability_nux|gpt-5.5=4' merged.txt ||
      fail "a runtime subtable of a declared table was dropped" merged.txt
    grep -qxF 'tui|theme=catppuccin-mocha' merged.txt ||
      fail "the declared value lost to the runtime one" merged.txt
    grep -qxF 'check_for_update_on_startup=False' merged.txt ||
      fail "a declared scalar lost to the runtime one" merged.txt
    grep -qxF "tui|status_line=['git-branch']" merged.txt ||
      fail "a declared list was not carried over" merged.txt
    grep -qxF 'mcp_servers|demo|command=/bin/demo' merged.txt ||
      fail "a declared table was not carried over" merged.txt

    cp statecase.toml once.toml
    ${merge} ${declared} "$PWD/statecase.toml"
    cmp -s once.toml statecase.toml || fail "a second merge changed the result" once.toml statecase.toml

    printf 'not = = toml [[[\n' >broken.toml
    if ${merge} ${declared} "$PWD/broken.toml" 2>broken.err; then
      fail "a corrupt config.toml was overwritten" broken.toml
    fi
    grep -q 'Refusing to overwrite' broken.err || fail "wrong message for a corrupt target" broken.err
    grep -qxF 'not = = toml [[[' broken.toml || fail "the corrupt target was modified anyway" broken.toml

    ${merge} ${declared} "$PWD/fresh/config.toml"
    [ -f fresh/config.toml ] || fail "a missing target was not created"

    if ${merge} ${declared} 2>usage.err; then
      fail "a missing argument was accepted" usage.err
    fi
    grep -q 'usage:' usage.err || fail "expected a usage error" usage.err

    echo "codex: config.toml merge checks OK"
    touch "$out"
  ''
