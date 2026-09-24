{
  inputs,
  lib,
  pkgs,
  ...
}: let
  root = "${inputs.mattpocock-skills}/skills";

  # Upstream's agents/openai.yaml is Codex UI metadata our targets don't read.
  upstreamSkill = path: let
    skill = lib.custom.ai.fromClaudeSkillDir {
      inherit pkgs;
      source = "${root}/${path}";
    };
  in
    removeAttrs skill ["resourcesRoot"]
    // lib.optionalAttrs (builtins.pathExists "${root}/${path}/scripts") {
      resourcesRoot = pkgs.runCommand "mattpocock-skill-resources" {} ''
        mkdir -p "$out" && cp -R ${root}/${path}/scripts "$out/"
      '';
    };

  diagnosingBugs = upstreamSkill "engineering/diagnosing-bugs";
in {
  programs.code-assistant-profiles.addons.mattpocock-skills = {
    skills = {
      grilling = upstreamSkill "productivity/grilling";

      # Upstream paths are relative to the skill dir, which is never the cwd.
      diagnosing-bugs =
        diagnosingBugs
        // {
          prompt.text = lib.replaceStrings ["`scripts/hitl-loop.template.sh`"] ["`\${SKILL_DIR}/scripts/hitl-loop.template.sh`"] diagnosingBugs.prompt.text;
        };

      # Ends by committing and continuing the rebase, so only on request.
      resolving-merge-conflicts = upstreamSkill "engineering/resolving-merge-conflicts" // {invocation.model = false;};
    };
  };
}
