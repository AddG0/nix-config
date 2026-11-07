# The Prismantis settings and plugin directory, and claude-hud's status line, this Claude setup writes into every profile.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  evalPrismantis = package:
    harness.eval [
      (harness.module (harness.root + "/modules/home/programs/claude-code"))
      ../prismantis.nix
      {
        options.lib = lib.mkOption {type = lib.types.attrsOf lib.types.anything;};
        config.lib.stylix.colors.withHashtag = lib.genAttrs (map (n: "base0${n}") ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" "F"]) (name: "#${name}");
        config.programs.claude-code-profiles = {
          enable = true;
          inherit package;
          profiles.default = {};
        };
      }
    ];
  rendered = harness.files (evalPrismantis harness.stubs.claude).home.file;
  statusLine = extra:
    (harness.eval [
      (harness.module (harness.root + "/modules/home/programs/claude-code"))
      ../hud-status-line.nix
      {
        _module.args.customPkgs.claude-hud = "/claude-hud";
        programs.claude-code-profiles = {
          enable = true;
          package = harness.stubs.claude;
          profiles.default = {};
        };
        claude-hud.extraCommand = extra;
      }
    ])
    .programs
    .claude-code-profiles
    .baseConfig
    .settings
    .statusLine
    .command;
  settings = ".config/claude-code/profiles/default/settings.json";
  prismantis = ''.pluginConfigs["prismantis@inline"]'';
in
  harness.check "claude-code-prismantis-files" ''
    ${rendered.jq "Prismantis settings sit under its plugin config's options, where the plugin reads them" settings "${prismantis} | keys == [\"options\"]"}
    ${rendered.jq "Prismantis gets the catppuccin theme with its prompt style off" settings "${prismantis}.options | .theme == \"catppuccin-mocha\" and .promptStyle == \"off\""}
    ${rendered.jq "Prismantis colours come from the stylix palette" settings "${prismantis}.options | .accentColor == \"#base0D\" and .diffRemovedColor == \"#base08\""}
    ${harness.paths.exists "Claude Code accepts the Prismantis plugin directory while the wrapper builds" "${(evalPrismantis pkgs.claude-code).programs.claude-code-profiles.wrapperPackage}/bin/claude"}
    ${harness.values {
      "test claude-hud runs with no extra segment until a module adds one" = {
        expr = lib.hasInfix "--extra-cmd" (statusLine null);
        expected = false;
      };
      "test claude-hud gets another module's extra command single-quoted, so its own shell expands the runtime directory" = {
        expr = lib.hasSuffix "/claude-hud/share/claude-code/plugins/claude-hud/dist/index.js --extra-cmd '/bin/segment \"$XDG_RUNTIME_DIR/ai-usage/report.json\"'" (statusLine "/bin/segment \"$XDG_RUNTIME_DIR/ai-usage/report.json\"");
        expected = true;
      };
    }}
  ''
