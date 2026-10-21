# Claude Code settings hooks (https://code.claude.com/docs/en/hooks): the typed option, its rendering and its checks.
{
  lib,
  mkHookSchema,
}: let
  toolEvents = ["PreToolUse" "PostToolUse" "PostToolUseFailure" "PermissionRequest" "PermissionDenied"];

  noMatcherEvents = ["UserPromptSubmit" "PostToolBatch" "Stop" "TeammateIdle" "TaskCreated" "TaskCompleted" "WorktreeCreate" "WorktreeRemove" "MessageDisplay" "CwdChanged"];

  events =
    toolEvents
    ++ noMatcherEvents
    ++ ["SessionStart" "Setup" "UserPromptExpansion" "Notification" "SubagentStart" "SubagentStop" "StopFailure" "InstructionsLoaded" "ConfigChange" "DirectoryAdded" "FileChanged" "PreCompact" "PostCompact" "PreModelSwitch" "PostModelSwitch" "Elicitation" "ElicitationResult" "SessionEnd"];

  field = type: description: {inherit type description;};

  schema = mkHookSchema {
    inherit events;

    fields = {
      "if" = field lib.types.str "Permission rule, such as `Bash(git *)`, the tool call must match. Tool events only.";
      timeout = field lib.types.ints.positive "Seconds before the handler is cancelled.";
      statusMessage = field lib.types.str "Spinner text shown while the handler runs.";
      once = field lib.types.bool "Remove the handler after its first successful run. Skill frontmatter only.";
      command = field lib.types.str "command: shell command, or the executable when `args` is set.";
      args = field (lib.types.listOf lib.types.str) "command: argument vector; setting it, even to `[]`, runs `command` without a shell.";
      async = field lib.types.bool "command: run in the background without blocking.";
      asyncRewake = field lib.types.bool "command: run in the background and wake Claude on exit code 2.";
      shell = field (lib.types.enum ["bash" "powershell"]) "command: shell for the shell form.";
      onFailure = field (lib.types.enum ["continue" "block"]) "command, http: whether the triggering action goes ahead when the handler fails.";
      url = field lib.types.str "http: URL the event is POSTed to.";
      headers = field (lib.types.attrsOf lib.types.str) "http: extra headers; `$VAR` expands only for `allowedEnvVars`.";
      allowedEnvVars = field (lib.types.listOf lib.types.str) "http: environment variables that may expand in `headers`.";
      server = field lib.types.str "mcp_tool: configured MCP server name.";
      tool = field lib.types.str "mcp_tool: tool to call on `server`.";
      input = field (lib.types.attrsOf lib.types.anything) "mcp_tool: tool arguments; strings take `\${path}` substitutions from the hook input.";
      prompt = field lib.types.str "prompt, agent: text sent to the model; `$ARGUMENTS` stands for the hook input.";
      model = field lib.types.str "prompt, agent: model that evaluates the prompt.";
      continueOnBlock = field lib.types.bool "prompt: feed an `ok: false` reason back to Claude instead of ending the turn.";
    };

    commonFields = ["if" "timeout" "statusMessage" "once"];

    typeFields = {
      command = ["command" "args" "async" "asyncRewake" "shell" "onFailure"];
      http = ["url" "headers" "allowedEnvVars" "onFailure"];
      mcp_tool = ["server" "tool" "input"];
      prompt = ["prompt" "model" "continueOnBlock"];
      agent = ["prompt" "model"];
    };

    requiredFields = {
      command = ["command"];
      http = ["url"];
      mcp_tool = ["server" "tool"];
      prompt = ["prompt"];
      agent = ["prompt"];
    };

    matcherDescription = "Filter on the event's matcher field (tool name, session source, ...). Omitted matches everything.";

    eventChecks = {
      group = {
        event,
        where,
        group,
      }:
        lib.optional ((group.matcher or null) != null && lib.elem event noMatcherEvents)
        "${where} sets matcher '${group.matcher}', but ${event} has no matcher support, so Claude Code ignores it";

      # context is the location: "settings", "agent" or "skill" — `once` is honoured only in skill frontmatter.
      handler = {
        at,
        context,
        event,
        handler,
      }:
        lib.optional ((handler."if" or null) != null && !(lib.elem event toolEvents))
        "${at} sets `if`, which Claude Code evaluates only on ${lib.concatStringsSep ", " toolEvents}; on ${event} the handler would never run"
        ++ lib.optional ((handler.once or null) != null && context != "skill")
        "${at} sets `once`, which Claude Code honours only in skill frontmatter";
    };
  };

  inherit (schema) hooksType problems render;

  # Raw attrsets, as frontmatter `extra` carries them, checked against the same type.
  typeHooks = prefix: raw:
    (lib.evalModules {
      inherit prefix;
      modules = [
        {
          options.hooks = lib.mkOption {type = hooksType;};
          config.hooks = raw;
        }
      ];
    }).config.hooks;
in {
  inherit events hooksType noMatcherEvents problems render toolEvents typeHooks;
}
