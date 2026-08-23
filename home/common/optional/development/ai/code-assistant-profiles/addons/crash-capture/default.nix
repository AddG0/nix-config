_: {
  programs.code-assistant-profiles.addons.crash-capture = {
    skills."diagnose-crash".prompt.source = ./skills/diagnose-crash/prompt.md;
  };
}
