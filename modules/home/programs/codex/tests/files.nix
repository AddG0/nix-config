{
  harness,
  pkgs,
  lib,
  self,
  ...
}: let
  # Activation scripts bake in absolute paths, so the test rewrites this prefix to its build dir.
  home = "/codex-test-home";

  evalHomeWith = preferXdgDirectories: codexConfig:
    (self.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../default.nix
        {
          home = {
            username = "t";
            homeDirectory = home;
            stateVersion = "25.05";
            inherit preferXdgDirectories;
          };
          programs.codex = {enable = true;} // codexConfig;
        }
      ];
    })
    .config;
  evalHome = evalHomeWith true;

  # Upstream's own CODEX_HOME, read off the AGENTS.md key it writes, against ours, for each XDG preference and config format.
  codexHomeCases = lib.cartesianProduct {
    preferXdg = [true false];
    version = ["0.1.0" "0.163.0"];
  };
  codexHomeOf = case: let
    config = evalHomeWith case.preferXdg {
      package = pkgs.writeShellScriptBin "codex-${case.version}" "";
      context = "x";
    };
  in {
    inherit case;
    upstream = lib.removeSuffix "/AGENTS.md" (lib.findSingle (lib.hasSuffix "/AGENTS.md") null null (lib.attrNames config.home.file));
    ours = import ../codex-home.nix {inherit config lib;};
  };
  codexHomes = map codexHomeOf codexHomeCases;

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
    profiles.alt.model_reasoning_effort = "high";
  };

  immutable = evalHome {
    settings = declared;
    profiles.alt.model_reasoning_effort = "high";
  };

  configKey = "/.config/codex/config.toml";
  profileKey = "/.config/codex/alt.config.toml";
  baseMerge = configured.home.activation.codexMutableSettings;
  profileMerge = configured.home.activation."codexMutableProfile-alt";

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
    ${harness.values {
      "test config.toml is merged at activation, not linked" = {
        expr = configured.home.file ? ${configKey};
        expected = false;
      };
      "test a profile file is merged at activation, not linked" = {
        expr = configured.home.file.${profileKey}.enable;
        expected = false;
      };
      "test the config.toml merge waits for linkGeneration" = {
        expr = baseMerge.after;
        expected = ["linkGeneration"];
      };
      "test the profile merge waits for linkGeneration" = {
        expr = profileMerge.after;
        expected = ["linkGeneration"];
      };
      "test an immutable config keeps its profile file linked" = {
        expr = immutable.home.file.${profileKey}.enable;
        expected = true;
      };
      "test an immutable config adds no profile merge" = {
        expr = immutable.home.activation ? "codexMutableProfile-alt";
        expected = false;
      };
      "test our CODEX_HOME matches upstream programs.codex's home.file keys for every XDG preference and config format" = {
        expr = codexHomes;
        expected = map (home: home // {ours = home.upstream;}) codexHomes;
      };
    }}

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
    profile=home/.config/codex/alt.config.toml

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
