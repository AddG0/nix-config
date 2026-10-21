# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  self,
  ...
}: let
  # Activation scripts bake in absolute paths, so the test rewrites this prefix to its build dir.
  home = "/codex-test-home";

  evalHome = codexConfig:
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./default.nix
        {
          home = {
            username = "t";
            homeDirectory = home;
            stateVersion = "25.05";
            preferXdgDirectories = true;
          };
          programs.codex = {enable = true;} // codexConfig;
        }
      ];
    })
    .config;

  declared = {
    check_for_update_on_startup = false;
    tui = {
      theme = "catppuccin-mocha";
      status_line = ["git-branch"];
    };
    mcp_servers.demo.command = "/bin/demo";
  };

  configured = evalHome {
    mutableSettings = true;
    settings = declared;
    profiles.work.model_reasoning_effort = "high";
  };

  immutable = evalHome {
    settings = declared;
    profiles.work.model_reasoning_effort = "high";
  };

  legacy = evalHome {
    mutableConfig.enable = true;
    settings = declared;
  };

  configKey = "/.config/codex/config.toml";
  profileKey = "/.config/codex/work.config.toml";
  baseMerge = configured.home.activation.codexMutableSettings;
  profileMerge = configured.home.activation."codexMutableProfile-work";

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

  script = name: entry:
    pkgs.writeText name ''
      set -euo pipefail
      errorEcho() { echo "$*" >&2; }
      ${entry.data}
    '';

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
  pkgs.runCommand "codex-mutable-settings-test" {nativeBuildInputs = [pkgs.gnused];} ''
    ${expect "config.toml is merged at activation, not linked" (configured.home.file ? ${configKey}) false}
    ${expect "a profile file is merged at activation, not linked" configured.home.file.${profileKey}.enable false}
    ${expect "the config.toml merge waits for linkGeneration" baseMerge.after ["linkGeneration"]}
    ${expect "the profile merge waits for linkGeneration" profileMerge.after ["linkGeneration"]}
    ${expect "an immutable config keeps its profile file linked" immutable.home.file.${profileKey}.enable true}
    ${expect "an immutable config adds no profile merge" (immutable.home.activation ? "codexMutableProfile-work") false}
    ${expect "the removed mutableConfig.enable still turns on mutableSettings" legacy.programs.codex.mutableSettings true}
    ${expect "the removed mutableConfig.enable warns to use mutableSettings" (lib.any (lib.hasInfix "programs.codex.mutableSettings") legacy.warnings) true}

    fail() {
      echo "FAIL: $1" >&2
      shift
      for f in "$@"; do
        echo "--- $f" >&2
        cat "$f" >&2
      done
      exit 1
    }

    activate() {
      sed "s|${home}|$PWD/home|g" "$1" >activate.sh
      bash activate.sh
    }

    target=home/.config/codex/config.toml
    profile=home/.config/codex/work.config.toml

    activate ${script "base" baseMerge}
    [ -f "$target" ] || fail "a missing config.toml was not created"
    [ -w "$target" ] || fail "the merged config is not writable"
    [ "$(stat -c%a "$target")" = "600" ] || fail "expected mode 600, got $(stat -c%a "$target")"

    rm "$target"
    cp ${runtimeState} "$target"
    chmod 600 "$target"
    activate ${script "base" baseMerge}

    ${reader} "$target" \
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
    [ "$(stat -c%a "$target")" = "600" ] || fail "the merge changed an existing file's mode"

    cp "$target" once.toml
    activate ${script "base" baseMerge}
    cmp -s once.toml "$target" || fail "a second merge changed the result" once.toml "$target"

    printf 'not = = toml [[[\n' >"$target"
    if activate ${script "base" baseMerge} 2>broken.err; then
      fail "a corrupt config.toml was overwritten" "$target"
    fi
    grep -q 'Could not parse config' broken.err || fail "wrong message for a corrupt target" broken.err
    grep -qxF 'not = = toml [[[' "$target" || fail "the corrupt target was modified anyway" "$target"

    rm "$target"
    ln -s ${runtimeState} "$target"
    if activate ${script "base" baseMerge} 2>link.err; then
      fail "a config.toml linked into the store was replaced"
    fi
    grep -q 'resolves into the Nix store' link.err || fail "wrong message for a store link" link.err
    [ -L "$target" ] || fail "the store link was modified anyway"

    activate ${script "profile" profileMerge}
    [ "$(stat -c%a "$profile")" = "600" ] || fail "expected profile mode 600, got $(stat -c%a "$profile")"
    printf '[projects."/home/someone/repo"]\ntrust_level = "trusted"\n' >>"$profile"
    activate ${script "profile" profileMerge}
    ${reader} "$profile" 'projects|/home/someone/repo|trust_level' 'model_reasoning_effort' >profile.txt
    grep -qxF 'projects|/home/someone/repo|trust_level=trusted' profile.txt ||
      fail "project trust written under a profile was dropped" profile.txt
    grep -qxF 'model_reasoning_effort=high' profile.txt ||
      fail "the declared profile setting was not carried over" profile.txt

    printf 'not = = toml [[[\n' >"$profile"
    if activate ${script "profile" profileMerge} 2>profile-broken.err; then
      fail "a corrupt profile file was overwritten" "$profile"
    fi
    grep -q 'Could not parse config' profile-broken.err || fail "wrong message for a corrupt profile file" profile-broken.err
    grep -qxF 'not = = toml [[[' "$profile" || fail "the corrupt profile file was modified anyway" "$profile"

    echo "codex: mutable settings checks OK"
    touch "$out"
  ''
