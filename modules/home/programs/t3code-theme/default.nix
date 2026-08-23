# Installs a declarative theme into t3code, which has no config-file setting for
# one — the library and selected id live only in browser localStorage — so the
# palette ships as a boot script patched into the client bundle.
#
# Patched into `unwrapped`: stdenv skips fixupPhase when `buildCommand` is set,
# so postFixup on the `t3code` symlinkJoin is a silent no-op.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.t3code.theme;

  hexColor =
    lib.types.strMatching
    "#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})";

  # Channel sum rather than true luminance; t3code only wants light-or-dark. A
  # missing canvas falls through to the contract check, which names the role.
  canvas = lib.removePrefix "#" (cfg.colors.canvas or "#000000");
  channel = offset: (builtins.fromTOML "v = 0x${builtins.substring offset 2 canvas}").v;
  canvasBrightness = channel 0 + channel 2 + channel 4;

  theme = {
    inherit (cfg) id label appearance colors;
  };

  bootScript = import ./boot-script.nix {inherit pkgs theme;};

  # What the boot script assumes about t3code's internals, checked against the
  # built client so a rename upstream fails the build rather than unthemes it.
  themeContract = pkgs.writeText "t3code-theme-contract.json" (builtins.toJSON {
    storageKeys = [
      "t3code:themes:v1"
      "t3code:theme"
      "t3code:theme-appearance-mode"
      "t3code:theme-follow-system"
      "t3code:theme-halves:v1"
    ];
    inherit theme;
  });

  clientRoot = "$out/libexec/t3code/apps/server/dist/client";
  iconLink = ''<link rel="apple-touch-icon" href="/apple-touch-icon.png" />'';

  themed = cfg.basePackage.override {
    t3code-unwrapped = cfg.basePackage.unwrapped.overrideAttrs (old: {
      postFixup =
        (old.postFixup or "")
        + ''
          node ${./assert-theme-contract.mjs} "${clientRoot}" ${themeContract}
          install -m444 ${bootScript} "${clientRoot}/install-theme.js"
          substituteInPlace "${clientRoot}/index.html" \
            --replace-fail \
              '${iconLink}' \
              '${iconLink}<script src="/install-theme.js"></script>'
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = cfg.basePackage.resourceMonitor;
  };
in {
  options.programs.t3code.theme = {
    enable = lib.mkEnableOption "a declarative t3code theme";

    id = lib.mkOption {
      type = lib.types.strMatching "[a-z0-9][a-z0-9-]{0,47}";
      default = "managed";
      description = ''
        Theme id, as stored in t3code's theme library. Must not collide with a
        built-in ("t3-chat", "grove", "ocean", "ember", "iris") — the build-time
        contract check runs t3code's own guard, which rejects reserved ids.
      '';
    };

    label = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "Managed";
      description = "Name shown in t3code's theme picker.";
    };

    appearance = lib.mkOption {
      type = lib.types.enum ["light" "dark"];
      default =
        if canvasBrightness < 384
        then "dark"
        else "light";
      defaultText = lib.literalMD "derived from `colors.canvas`";
      description = ''
        Which mode the palette is. Drives `color-scheme`, so form controls and
        scrollbars follow it.
      '';
    };

    colors = lib.mkOption {
      type = lib.types.attrsOf hexColor;
      default = {};
      example = lib.literalExpression ''
        {
          canvas = "#1e1e2e";
          text = "#cdd6f4";
          accent = "#89b4fa";
        }
      '';
      description = ''
        Every colour role in t3code's palette, as `#rrggbb`. The role set is
        checked against the built client, so a role added or dropped upstream
        fails the build rather than silently falling back to t3code's default.
      '';
    };

    basePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.t3code;
      defaultText = lib.literalExpression "pkgs.t3code";
      description = "The t3code package to patch the theme into.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.programs.t3code.enable;
        message = "programs.t3code.theme needs programs.t3code.enable — the theme is built into the package, so nothing installs it on its own.";
      }
      {
        assertion = config.programs.t3code.package != null;
        message = "programs.t3code.theme cannot apply with programs.t3code.package set to null, which discards the themed build.";
      }
    ];

    programs.t3code.package = lib.mkDefault themed;
  };
}
