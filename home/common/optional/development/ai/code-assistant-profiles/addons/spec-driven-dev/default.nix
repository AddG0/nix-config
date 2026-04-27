_: {
  agents = {
    "system-architect".prompt.source = ./02-spec/agents/system-architect.md;
    "spec-requirements-validator".prompt.source = ./02-spec/agents/spec-requirements-validator.md;
    "spec-design-validator".prompt.source = ./02-spec/agents/spec-design-validator.md;
    "spec-task-validator".prompt.source = ./02-spec/agents/spec-task-validator.md;
    "tdd-test-writer".prompt.source = ./03-implementation/agents/tdd-test-writer.md;
    "tdd-implementer".prompt.source = ./03-implementation/agents/tdd-implementer.md;
    "tdd-refactorer".prompt.source = ./03-implementation/agents/tdd-refactorer.md;
    "spec-task-executor".prompt.source = ./03-implementation/agents/spec-task-executor.md;
    "task-completion-validator".prompt.source = ./04-quality/agents/task-completion-validator.md;
    "spec-reviewer".prompt.source = ./04-quality/agents/spec-reviewer.md;
    "silent-failure-hunter".prompt.source = ./04-quality/agents/silent-failure-hunter.md;
    "acceptance-tester".prompt.source = ./04-quality/agents/acceptance-tester.md;
  };

  skills = {
    "spec-steering-setup" = {
      prompt.source = ./00-steering/skills/spec-steering-setup/prompt.md;
      resourcesRoot = ./00-steering/skills/spec-steering-setup/resources;
    };
    "interview".prompt.source = ./01-discovery/skills/interview/prompt.md;
    "spec-create" = {
      prompt.source = ./02-spec/skills/spec-create/prompt.md;
      resourcesRoot = ./02-spec/skills/spec-create/resources;
    };
    "spec-status".prompt.source = ./02-spec/skills/spec-status/prompt.md;
    "architecture-standards" = {
      prompt.source = ./02-spec/skills/architecture-standards/prompt.md;
      resourcesRoot = ./02-spec/skills/architecture-standards/resources;
    };
    "adr".prompt.source = ./02-spec/skills/adr/prompt.md;
    "tdd-cycle".prompt.source = ./03-implementation/skills/tdd-cycle/prompt.md;
    "spec-execute".prompt.source = ./03-implementation/skills/spec-execute/prompt.md;
    "spec-mutate".prompt.source = ./04-quality/skills/spec-mutate/prompt.md;
    "bug-create" = {
      prompt.source = ./05-bugs/skills/bug-create/prompt.md;
      resourcesRoot = ./05-bugs/skills/bug-create/resources;
    };
    "bug-fix".prompt.source = ./05-bugs/skills/bug-fix/prompt.md;
  };

  rules = {
    "spec-driven".content.source = ./rules.md;
    "quality-standards".content.source = ./04-quality/rules/quality-standards.md;
    architecture.content.text = ''
      Architecture conventions:
      - Document significant decisions as ADRs in .sdd/specs/decisions/ (MADR 3.0 format)
      - Use Mermaid for inline diagrams, C4 model for system-level views
      - Always document trade-offs — what was chosen AND what was rejected and why
      - Respect existing ADRs — flag contradictions, create new ADR if overriding
    '';
  };
}
