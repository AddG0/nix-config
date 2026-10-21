# Checks only the Claude target makes: hooks carried in agent and skill frontmatter through extra.claude-code.
{
  claudeSettingsHooks,
  lib,
}: let
  hookProblems = scope: kind: entries:
    lib.concatLists (lib.mapAttrsToList (name: entry: let
      raw = entry.extra.claude-code;
    in
      lib.optionals (raw ? hooks) (map (problem: "${scope} ${kind} '${name}' extra.claude-code.hooks: ${problem}")
        (claudeSettingsHooks.problems kind (claudeSettingsHooks.typeHooks ["code-assistant-profiles" "${kind}s" name "extra" "claude-code"] raw.hooks))))
    entries);
in {
  frontmatterHookProblems = scope: profile:
    hookProblems scope "agent" profile.agents
    ++ hookProblems scope "skill" profile.skills;
}
