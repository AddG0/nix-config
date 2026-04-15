_: {
  skills = {
    "nix-build" = {
      prompt.source = ./skills/nix-build/prompt.md;
    };

    "dev-flake" = {
      prompt.source = ./skills/dev-flake/prompt.md;
      resourcesRoot = ./skills/dev-flake/resources;
    };
  };

  agents."nix-builder" = {
    prompt.source = ./agents/nix-builder.md;
  };
}
