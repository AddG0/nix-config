# The schema of one rule entry.
{lib}: let
  inherit (import ./fields.nix {inherit lib;}) textSourceType extraOption;
in
  lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Rule name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of what the rule covers.";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["src/api/**/*.ts" "**/*.test.ts"];
        description = "Optional glob patterns that scope when the rule should apply.";
      };

      content = lib.mkOption {
        type = textSourceType;
        default = {};
        description = "Rule content as inline text or a source file.";
      };

      extra = extraOption ["claude-code"] {
        claude-code = "Setting any turns a rule without paths from a bare file into one with frontmatter.";
      };
    };
  })
