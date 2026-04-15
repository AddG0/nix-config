# Spec-driven development addon
#
# Phases:
#   00-steering       — project context setup (product.md, tech.md, structure.md)
#   01-discovery      — interview & requirements gathering
#   02-spec           — spec creation pipeline with validation gates
#   03-implementation — TDD cycle (RED/GREEN/BLUE) & task execution
#   04-quality        — review, validation, acceptance testing, mutation testing
#   05-bugs           — structured bug reporting & fixing
{pkgs, ...}: let
  mkHook = name: inputs:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.jq pkgs.coreutils] ++ inputs;
      text = builtins.readFile ./hooks/${name}.sh;
    };

  specAwarenessHook = mkHook "spec-awareness" [pkgs.gnugrep pkgs.gnused];
  sessionStartHook = mkHook "session-start" [pkgs.gnugrep pkgs.gnused];
  postCompactHook = mkHook "post-compact" [pkgs.gnugrep];
  specChangelogHook = mkHook "spec-changelog" [];
  taskCompletedHook = mkHook "task-completed" [pkgs.gnugrep pkgs.git];
in {
  settings.permissions.allow = [
    "Write(.claude/specs/**)"
    "Edit(.claude/specs/**)"
    "Write(.claude/steering/**)"
    "Edit(.claude/steering/**)"
    "Bash(git checkout:*)"
    "Bash(git merge:*)"
    "Bash(git branch:*)"
    "Bash(git rebase:*)"
    "Bash(git worktree:*)"
  ];

  settings.companyAnnouncements = let
    lines = [
      "Spec-Driven Development"
      ""
      "Commands:"
      "  /spec-steering-setup       Set up project context (one-time)"
      "  /interview [topic]         Gather requirements interactively"
      "  /spec-create <feature>     Requirements → Design → Tasks with validation"
      "  /spec-execute <feat> [N]   Execute task in worktree (auto-continues, --no-worktree to skip)"
      "  /spec-status [feature]     Check progress"
      "  /tdd-cycle <feature>       RED → GREEN → BLUE TDD cycle"
      "  /adr <decision-title>      Create an Architecture Decision Record"
      "  /spec-mutate <feat> [N]    Mutation testing (optional)"
      "  /bug-create <description>  Structured bug report"
      "  /bug-fix <slug>            Fix + regression test + validate"
      ""
      "Quick fix:     /tdd-cycle → done"
      "Bug triage:    /bug-create → /bug-fix"
      "Full pipeline: /interview → /spec-create → /spec-execute → /spec-status"
    ];
  in [(builtins.concatStringsSep "\n" lines)];

  settings.hooks = {
    # Load steering context at session start; re-inject spec context after compaction
    SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "${sessionStartHook}/bin/session-start";
          }
        ];
      }
      {
        matcher = "compact";
        hooks = [
          {
            type = "command";
            command = "${postCompactHook}/bin/post-compact";
          }
        ];
      }
    ];

    # Inject active spec context before every prompt
    UserPromptSubmit = [
      {
        hooks = [
          {
            type = "command";
            command = "${specAwarenessHook}/bin/spec-awareness";
            timeout = 10;
          }
        ];
      }
    ];

    # Track changes to spec documents
    PostToolUse = [
      {
        matcher = "Edit|Write";
        hooks = [
          {
            type = "command";
            command = "${specChangelogHook}/bin/spec-changelog";
            async = true;
          }
        ];
      }
    ];

    # Validate task completion — blocks if build/tests fail or TODOs remain
    TaskCompleted = [
      {
        hooks = [
          {
            type = "command";
            command = "${taskCompletedHook}/bin/task-completed";
            timeout = 120;
          }
        ];
      }
    ];

    # Note: PostCompact is not a valid hook event. Post-compaction context
    # restoration is handled via SessionStart with matcher="compact" above.
  };
}
