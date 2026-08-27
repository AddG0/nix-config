{
  lib,
  typesModule,
}: {
  options.programs.code-assistant-profiles = {
    enable = lib.mkEnableOption "shared profile-based configuration for coding tools";

    defaultProfile = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Default shared profile name.";
    };

    baseConfig = lib.mkOption {
      type = lib.types.submodule {options = typesModule.sharedProfileOptions;};
      default = {};
      description = "Base shared configuration merged into all profiles by future adapters.";
    };

    defaultAgent = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["claude-code" "codex" "opencode"]);
      default = null;
      example = "claude-code";
      description = ''
        Target whose agent `agent-run` launches when no `--agent` is given.
        Names match `targets`, and the chosen target must be enabled.
      '';
    };

    launcher = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      readOnly = true;
      description = ''
        The `agent-run` launcher. Null when no target is enabled, and null
        while `enable` is false, so a consumer can test it without also
        testing `enable`.
      '';
    };

    budgets = lib.mkOption {
      type = lib.types.submodule {
        options = {
          alwaysOn = lib.mkOption {
            type = lib.types.submodule {
              options = {
                lines = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = 200;
                  description = ''
                    Line budget for everything a session loads before its first
                    prompt: `instructions` plus every rule without `paths`.
                    Anthropic documents 200 lines as the point past which
                    adherence drops (<https://code.claude.com/docs/en/memory>).
                    Null disables the check.
                  '';
                };

                characters = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = 20000;
                  description = ''
                    Character budget over the same content, roughly 5k tokens.
                    The line budget alone under-counts prose written as long
                    unwrapped lines, which is how most rules here are written.
                    Null disables the check.
                  '';
                };
              };
            };
            default = {};
            description = "Budget for content loaded into every session up front.";
          };

          description = lib.mkOption {
            type = lib.types.submodule {
              options = {
                total = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  example = 40000;
                  description = ''
                    Budget for all selection text in a profile combined: every
                    skill's `description` plus `whenToUse`, and every agent's
                    `description`. Claude Code preloads the lot so the model can
                    choose between them.

                    Null derives it from `contextWindow`, which is usually what
                    you want — the real limit scales with the window. Set an
                    integer to pin it, or set `contextWindow` to null to drop the
                    check entirely.
                  '';
                };

                characters = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = 1536;
                  description = ''
                    Per-entry ceiling. Claude Code truncates a single skill's
                    selection text past 1536 characters and warns at startup. This
                    is the breakage point, not the style guide — addons/CLAUDE.md
                    asks for 150 and that stays a matter for review. Null disables
                    the check.
                  '';
                };
              };
            };
            default = {};
            description = "Budget for the selection text preloaded for each skill and agent.";
          };

          contextWindow = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = 200000;
            example = 1000000;
            description = ''
              Context window, in tokens, of the model these profiles actually run
              against. Claude Code gives the skill listing 1% of it by default
              (`SLASH_COMMAND_TOOL_CHAR_BUDGET` overrides), which is what
              `description.total` derives from when left null. Set this to the
              window you really use — budgeting a 1M-token model as though it
              were 200K just manufactures warnings. Null drops the derived check.
            '';
          };

          enforce = lib.mkOption {
            type = lib.types.enum ["off" "warn" "error"];
            default = "warn";
            description = ''
              What exceeding a budget does. `warn` reports it and still builds,
              which suits a budget you are meant to weigh rather than obey.
            '';
          };
        };
      };
      default = {};
      description = "Context budgets, checked per resolved profile.";
    };

    addons = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {options = typesModule.sharedProfileOptions;});
      default = {};
      description = "Named, reusable shared-profile content blocks that profiles can include via the `include` option.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf typesModule.profileType;
      default = {};
      description = ''
        Named shared profile definitions for coding tools.

        Only `defaultProfile` reaches the codex and opencode targets, which render
        a single profile each. Claude Code renders every profile, so extra profiles
        here are Claude-Code-only.
      '';
    };

    targets = lib.mkOption {
      type = lib.types.submodule {
        options = {
          claude-code.enable = lib.mkEnableOption "rendering shared profiles for Claude Code (drives programs.claude-code-profiles.enable)";
          opencode.enable = lib.mkEnableOption "rendering shared profiles for opencode (drives programs.opencode.enable)";
          codex.enable = lib.mkEnableOption "rendering shared profiles for OpenAI Codex CLI (drives programs.codex.enable)";
        };
      };
      default = {};
      description = "Per-tool rendering target toggles. Enable each target to flow shared profiles into the corresponding tool module.";
    };

    resolved = lib.mkOption {
      type = lib.types.attrsOf typesModule.resolvedProfileType;
      readOnly = true;
      internal = true;
      description = "Fully resolved profile configs after applying baseConfig and extends.";
    };
  };
}
