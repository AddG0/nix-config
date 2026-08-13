_: {
  programs.code-assistant-profiles.addons.design-notes = {
    agents = {
      "requirements-reviewer".prompt.source = ./agents/requirements-reviewer.md;
      "design-reviewer".prompt.source = ./agents/design-reviewer.md;
    };

    skills = {
      "steering-setup" = {
        prompt.source = ./skills/steering-setup/prompt.md;
        resourcesRoot = ./skills/steering-setup/resources;
      };
      "interview".prompt.source = ./skills/interview/prompt.md;
      "notes-status".prompt.source = ./skills/notes-status/prompt.md;
    };

    rules."design-notes".content.source = ./rules/design-notes.md;
  };
}
