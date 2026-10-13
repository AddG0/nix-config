_: {
  programs.code-assistant-profiles.addons.handoff = {
    skills.handoff = {
      prompt.source = ./skills/handoff/prompt.md;
      invocation.model = false;
    };

    rules.context.content.source = ./rules/context.md;
  };
}
