{
  config,
  lib,
  ...
}: let
  prompt = ./skills/work/prompt.md;

  # A router that names a missing skill sends you nowhere, so fail the build instead.
  builtins' = ["clear" "compact"];
  referenced = lib.unique (map lib.head (lib.filter lib.isList (builtins.split "`/([a-z_-]+)" (builtins.readFile prompt))));
  profile = config.programs.code-assistant-profiles.resolved.default;
  available = lib.attrNames profile.skills ++ lib.attrNames profile.commands ++ builtins';
  missing = lib.subtractLists available referenced;
in {
  programs.code-assistant-profiles.addons.work = {
    skills.work = {
      prompt.source = prompt;
      invocation.model = false;
    };
  };

  assertions = [
    {
      assertion = missing == [];
      message = "work router (addons/work/skills/work/prompt.md) names skills the default profile lacks: ${lib.concatStringsSep ", " missing}";
    }
  ];
}
