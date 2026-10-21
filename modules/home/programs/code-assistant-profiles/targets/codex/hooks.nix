# Codex hooks (codex-rs/config/src/hook_config.rs, rust-v0.163.0): the typed option, its rendering and its checks.
{
  lib,
  mkHookSchema,
}: let
  noMatcherEvents = ["UserPromptSubmit" "Stop" "Interrupt"];

  # Run with a 1 s default and a 3 s ceiling.
  shortEvents = ["SessionEnd" "Interrupt"];
  shortEventTimeoutCeiling = 3;

  events =
    noMatcherEvents
    ++ ["PreToolUse" "PermissionRequest" "PostToolUse" "PreCompact" "PostCompact" "SessionStart" "SessionEnd" "SubagentStart" "SubagentStop"];

  contextEvents = ["PreToolUse" "PostToolUse" "SessionStart" "UserPromptSubmit" "SubagentStart"];

  hasNull = value:
    value
    == null
    || (lib.isAttrs value && lib.any hasNull (lib.attrValues value))
    || (lib.isList value && lib.any hasNull value);

  field = type: description: {inherit type description;};

  schema = mkHookSchema {
    inherit events;

    fields = {
      timeout = field lib.types.ints.positive "Seconds before the handler is cancelled (default 600; 1 on SessionEnd and Interrupt, at most 3).";
      statusMessage = field lib.types.str "Status text shown while the handler runs.";
      command = field lib.types.str "command: shell command, run in the session cwd.";
      commandWindows = field lib.types.str "command: Windows-only override of `command`.";
      async = field lib.types.bool "command: run in the background; it can no longer block or rewrite anything.";
      additionalContextLimit = field lib.types.ints.unsigned "command: approximate token count past which `additionalContext` spills to disk; 0 never spills.";
      server = field lib.types.str "mcp_tool: an already-connected MCP server.";
      tool = field lib.types.str "mcp_tool: tool to call on `server`.";
      input = field (lib.types.attrsOf lib.types.anything) "mcp_tool: tool arguments, with `\${field.nested}` templates from the hook input. Must be TOML-representable, so no nulls.";
    };

    commonFields = ["timeout" "statusMessage"];

    # prompt and agent parse but never run, so they are left out.
    typeFields = {
      command = ["command" "commandWindows" "async" "additionalContextLimit"];
      mcp_tool = ["server" "tool" "input"];
    };

    requiredFields = {
      command = ["command"];
      mcp_tool = ["server" "tool"];
    };

    matcherDescription = "Regex on the event's matcher field (tool name, compaction trigger, session source, ...). Omitted matches everything.";

    eventChecks = {
      group = {
        event,
        where,
        group,
      }:
        lib.optional (group.matcher != null && lib.elem event noMatcherEvents)
        "${where} sets matcher '${group.matcher}', but Codex ignores matchers on ${event}";

      handler = {
        at,
        event,
        handler,
        ...
      }:
        lib.optional (event == "SessionEnd" && handler.type == "mcp_tool")
        "${at} is an mcp_tool handler, which Codex does not run on SessionEnd"
        ++ lib.optional (event == "SessionEnd" && handler.async != null)
        "${at} sets `async`, but Codex always runs SessionEnd hooks synchronously"
        ++ lib.optional (lib.elem event shortEvents && handler.timeout != null && handler.timeout > shortEventTimeoutCeiling)
        "${at} sets timeout ${toString handler.timeout}, above the ${toString shortEventTimeoutCeiling} second ceiling Codex clamps ${event} to"
        ++ lib.optional (handler.additionalContextLimit != null && !(lib.elem event contextEvents))
        "${at} sets `additionalContextLimit`, but ${event} cannot emit additionalContext"
        ++ lib.optional (handler.input != null && hasNull handler.input)
        "${at} has a null in `input`, which Codex rejects because it must be TOML-representable";
    };
  };
in {
  inherit events;
  inherit (schema) hooksType render;
  problems = schema.problems null;
}
