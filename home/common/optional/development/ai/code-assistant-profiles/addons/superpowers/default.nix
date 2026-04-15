{
  pkgs,
  lib,
  ...
}: let
  skillNames = [
    "brainstorming"
    "dispatching-parallel-agents"
    "executing-plans"
    "finishing-a-development-branch"
    "receiving-code-review"
    "requesting-code-review"
    "subagent-driven-development"
    "systematic-debugging"
    "test-driven-development"
    "using-git-worktrees"
    "using-superpowers"
    "verification-before-completion"
    "writing-plans"
    "writing-skills"
  ];
  skillsPath = "${pkgs.superpowers-skills}/share/claude-code/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir;
in {
  skills = lib.listToAttrs (map (skill: {
      name = skill;
      value = fromClaudeSkillDir {
        inherit pkgs;
        source = "${skillsPath}/${skill}";
      };
    })
    skillNames);
}
