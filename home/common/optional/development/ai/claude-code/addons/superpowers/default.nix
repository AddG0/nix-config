# Superpowers addon - Claude Code Skills
# https://github.com/obra/superpowers
#
# A comprehensive software development workflow system for Claude Code.
# Emphasizes thoughtful progression: design refinement -> approval -> planning -> execution.
#
# SKILLS:
#   brainstorming - Structured ideation and design refinement with users
#   dispatching-parallel-agents - Coordinate multiple subagents for parallel task execution
#   executing-plans - Systematic execution of approved implementation plans
#   finishing-a-development-branch - Wrap up work on a branch with proper cleanup and handoff
#   receiving-code-review - Process and respond to code review feedback effectively
#   requesting-code-review - Prepare and submit code for review with proper context
#   subagent-driven-development - Dispatch fresh subagent per task with code review between tasks
#   systematic-debugging - Methodical approach to finding and fixing bugs
#   test-driven-development - Write tests first, then implement to pass them
#   using-git-worktrees - Manage multiple working directories for parallel development
#   using-superpowers - Meta-skill for using the superpowers system
#   verification-before-completion - Validate work before marking tasks complete
#   writing-plans - Create detailed implementation plans for approval
#   writing-skills - Meta-skill for creating new Claude Code skills
#
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
in {
  # Each skill is a directory
  skills = lib.listToAttrs (map (skill: {
      name = skill;
      value = "${skillsPath}/${skill}";
    })
    skillNames);
}
