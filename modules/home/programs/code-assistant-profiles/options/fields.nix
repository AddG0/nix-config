# Field types several entry kinds share.
{lib}: let
  textSourceType = lib.types.submodule {
    options = {
      text = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = "Inline content.";
      };

      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the content.";
      };
    };
  };

  # Claude Code's fixed set; a target with its own colour scheme translates these names.
  agentColors = ["blue" "cyan" "green" "orange" "pink" "purple" "red" "yellow"];

  reasoningEfforts = ["minimal" "low" "medium" "high" "xhigh" "max" "ultra"];

  reasoningEffortOption = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum reasoningEfforts);
    default = null;
    description = "Preferred reasoning effort level. Higher levels trade latency and cost for deeper analysis.";
  };

  # `notes` adds a sentence to one target's description.
  extraOption = targets: notes:
    lib.mkOption {
      type = lib.types.submodule {
        options = lib.genAttrs targets (target:
          lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
            description = "Fields merged last, recursively, into what ${target} reads for this entry. Not validated; ${target} ignores keys it does not know.${lib.optionalString (notes ? ${target}) " ${notes.${target}}"}";
          });
      };
      default = {};
      example = lib.literalExpression ''{${lib.head targets} = {someField = true;};}'';
      description = "Per-target passthrough for fields only one tool understands, merged over the rendered entry.";
    };
in {
  inherit agentColors extraOption reasoningEffortOption textSourceType;
}
