# Hook option, renderer and checks for tools whose hooks are events of matcher groups of typed handlers (Claude Code, Codex).
{lib}: {
  events,
  fields,
  commonFields,
  typeFields,
  requiredFields,
  matcherDescription,
  eventChecks ? {},
}: let
  groupChecks = eventChecks.group or (_: []);
  handlerChecks = eventChecks.handler or (_: []);

  nullable = field:
    lib.mkOption {
      type = lib.types.nullOr field.type;
      default = null;
      inherit (field) description;
    };

  backticked = map (field: "`${field}`") commonFields;

  handlerType = lib.types.submodule {
    options =
      lib.mapAttrs (_: nullable) fields
      // {
        type = lib.mkOption {
          type = lib.types.enum (lib.attrNames typeFields);
          description = "Handler kind. Each kind accepts only its own fields besides ${lib.concatStringsSep ", " (lib.init backticked)} and ${lib.last backticked}.";
        };
      };
  };

  matcherGroupType = lib.types.submodule {
    options = {
      matcher = nullable {
        type = lib.types.str;
        description = matcherDescription;
      };
      hooks = lib.mkOption {
        type = lib.types.listOf handlerType;
        description = "Handlers run when the matcher matches.";
      };
    };
  };

  hooksType = lib.types.submodule {
    options = lib.genAttrs events (event:
      lib.mkOption {
        type = lib.types.listOf matcherGroupType;
        default = [];
        description = "Matcher groups for the ${event} event.";
      });
  };

  renderHandler = lib.filterAttrs (_: value: value != null);

  renderGroup = group:
    lib.optionalAttrs ((group.matcher or null) != null) {inherit (group) matcher;}
    // {hooks = map renderHandler group.hooks;};

  # Typed values in, the tool's JSON shape out: unset fields and empty events dropped.
  render = hooks:
    lib.filterAttrs (_: groups: groups != []) (lib.genAttrs events (event: map renderGroup (hooks.${event} or [])));

  kindsWith = field: lib.attrNames (lib.filterAttrs (_: kindFields: lib.elem field kindFields) typeFields);

  # `context` is handed to eventChecks.handler untouched, for checks that depend on where the hooks are declared.
  problems = context: hooks:
    lib.concatLists (lib.concatMap (event:
      lib.imap0 (groupIndex: group: let
        where = "${event}[${toString groupIndex}]";
      in
        groupChecks {inherit event where group;}
        ++ lib.concatLists (lib.imap0 (handlerIndex: handler: let
          at = "${where}.hooks[${toString handlerIndex}] (type ${handler.type})";
          foreign = lib.subtractLists (["type"] ++ commonFields ++ typeFields.${handler.type}) (lib.attrNames (renderHandler handler));
          missing = lib.filter (field: (handler.${field} or null) == null) requiredFields.${handler.type};
        in
          map (field: "${at} sets `${field}`, which only applies to ${lib.concatStringsSep "/" (kindsWith field)} handlers") foreign
          ++ map (field: "${at} is missing required `${field}`") missing
          ++ handlerChecks {inherit at context event handler;})
        group.hooks))
      (hooks.${event} or []))
    events);
in {
  inherit hooksType problems render;
}
