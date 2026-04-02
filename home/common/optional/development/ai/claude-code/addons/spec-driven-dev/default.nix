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
  protectSteeringHook = mkHook "protect-steering" [];
  protectSpecsHook = mkHook "protect-specs" [];
  sessionStartHook = mkHook "session-start" [pkgs.gnugrep pkgs.gnused];
  postCompactHook = mkHook "post-compact" [pkgs.gnugrep];
  specChangelogHook = mkHook "spec-changelog" [];
in {
  agents = {
    # 02-spec: architecture + validation agents
    "system-architect" = ./02-spec/agents/system-architect.md;
    "adr-architect" = ./02-spec/agents/adr-architect.md;
    "spec-requirements-validator" = ./02-spec/agents/spec-requirements-validator.md;
    "spec-design-validator" = ./02-spec/agents/spec-design-validator.md;
    "spec-task-validator" = ./02-spec/agents/spec-task-validator.md;

    # 03-implementation: TDD agents + task executor
    "tdd-test-writer" = ./03-implementation/agents/tdd-test-writer.md;
    "tdd-implementer" = ./03-implementation/agents/tdd-implementer.md;
    "tdd-refactorer" = ./03-implementation/agents/tdd-refactorer.md;
    "spec-task-executor" = ./03-implementation/agents/spec-task-executor.md;

    # 04-quality: review, validation & acceptance agents
    "task-completion-validator" = ./04-quality/agents/task-completion-validator.md;
    "spec-reviewer" = ./04-quality/agents/spec-reviewer.md;
    "silent-failure-hunter" = ./04-quality/agents/silent-failure-hunter.md;
    "acceptance-tester" = ./04-quality/agents/acceptance-tester.md;
  };

  skills = {
    # 00-steering
    "spec-steering-setup" = ./00-steering/skills/spec-steering-setup;

    # 01-discovery
    "interview" = ./01-discovery/skills/interview;

    # 02-spec
    "spec-create" = ./02-spec/skills/spec-create;
    "spec-status" = ./02-spec/skills/spec-status;
    "architecture-standards" = ./02-spec/skills/architecture-standards;
    "adr" = ./02-spec/skills/adr;

    # 03-implementation
    "tdd-cycle" = ./03-implementation/skills/tdd-cycle;
    "spec-execute" = ./03-implementation/skills/spec-execute;

    # 04-quality
    "spec-mutate" = ./04-quality/skills/spec-mutate;

    # 05-bugs
    "bug-create" = ./05-bugs/skills/bug-create;
    "bug-fix" = ./05-bugs/skills/bug-fix;
  };

  rules = {
    "spec-driven" = builtins.readFile ./rules.md;
    "quality-standards" = builtins.readFile ./04-quality/rules/quality-standards.md;
    "architecture" = ''
      Architecture conventions:
      - Document significant decisions as ADRs in .claude/specs/decisions/ (MADR 3.0 format)
      - Use Mermaid for inline diagrams, C4 model for system-level views
      - Always document trade-offs — what was chosen AND what was rejected and why
      - Respect existing ADRs — flag contradictions, create new ADR if overriding
    '';
  };

  settings.permissions.allow = [
    "Write(.claude/specs:*)"
    "Edit(.claude/specs:*)"
    "Write(.claude/steering:*)"
    "Edit(.claude/steering:*)"
    "Write(.claude/specs/**)"
    "Edit(.claude/specs/**)"
    "Write(.claude/steering/**)"
    "Edit(.claude/steering/**)"
    "Bash(git checkout:*)"
    "Bash(git merge:*)"
    "Bash(git branch:*)"
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
          }
        ];
      }
    ];

    # Protect steering and spec docs from accidental modification
    PreToolUse = [
      {
        matcher = "Edit|Write";
        hooks = [
          {
            type = "command";
            command = "${protectSteeringHook}/bin/protect-steering";
          }
          {
            type = "command";
            command = "${protectSpecsHook}/bin/protect-specs";
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

    # Note: PostCompact is not a valid hook event. Post-compaction context
    # restoration is handled via SessionStart with matcher="compact" above.
  };
}
