# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  settings = {"org.gradle.parallel" = "true";};
  secret = {shqToken = "work_token";};
  renderedPath = "/home/tester/.config/sops-nix/secrets/rendered/gradle.properties";

  # Stand in for home-manager's gradle module and for sops-nix.
  stubs = {
    options.programs.gradle = {
      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
      };
      home = lib.mkOption {
        type = lib.types.str;
        default = ".gradle";
      };
    };
    options.home.file = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };
    options.lib = lib.mkOption {type = lib.types.attrsOf lib.types.anything;};
    options.sops.placeholder = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
    };
    options.sops.templates = lib.mkOption {
      default = {};
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          file = lib.mkOption {type = lib.types.path;};
          mode = lib.mkOption {type = lib.types.str;};
          path = lib.mkOption {
            type = lib.types.str;
            default = "/home/tester/.config/sops-nix/secrets/rendered/${name}";
          };
        };
      }));
    };
    config.sops.placeholder.work_token = "<SOPS:deadbeef:PLACEHOLDER>";
    config.lib.file.mkOutOfStoreSymlink = target: "symlink:${target}";
  };

  evalWith = module:
    (lib.evalModules {
      specialArgs = {inherit pkgs;};
      modules = [./default.nix stubs module];
    })
    .config;

  diverted = evalWith {
    programs.gradle = {
      inherit settings;
      secretSettings = secret;
    };
  };
  publicOnly = evalWith {programs.gradle = {inherit settings;};};

  template = diverted.sops.templates."gradle.properties";
in
  pkgs.runCommand "gradle-test" {} ''
    set -euo pipefail

    fail() {
      echo "$1" >&2
      exit 1
    }

    echo "stays out of the way when nothing is secret"
    [ ${toString (builtins.length (builtins.attrNames publicOnly.sops.templates))} -eq 0 ] \
      || fail "declared a sops template with no secret entries"
    [ ${toString (builtins.length (builtins.attrNames publicOnly.home.file))} -eq 0 ] \
      || fail "repointed gradle.properties with no secret entries"

    echo "renders settings and secrets into one file, at 0600"
    grep -qx 'org.gradle.parallel = true' ${template.file} || fail "settings entry missing from the template"
    grep -qx 'shqToken = <SOPS:deadbeef:PLACEHOLDER>' ${template.file} \
      || fail "placeholder missing or escaped in the template"
    [ ${lib.escapeShellArg template.mode} = 0600 ] || fail "wrong mode"

    echo "points gradle.properties at the rendered file"
    [ ${lib.escapeShellArg diverted.home.file.".gradle/gradle.properties".source} = symlink:${renderedPath} ] \
      || fail "gradle.properties was not repointed at the rendered file"

    touch $out
  ''
