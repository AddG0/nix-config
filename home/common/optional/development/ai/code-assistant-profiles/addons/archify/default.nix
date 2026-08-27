{
  inputs,
  lib,
  pkgs,
  ...
}: let
  source = "${inputs.archify}/archify";

  # The CLI finds its own package root, so the prompt never needs a cwd inside
  # the read-only skill dir.
  archify = pkgs.writeShellScriptBin "archify" ''
    exec ${lib.getExe pkgs.nodejs} ${source}/bin/archify.mjs "$@"
  '';

  # Upstream writes these relative to the skill dir, which is never the cwd.
  relativePaths = [
    "schemas/"
    "schemas/common.schema.json"
    "examples/"
    "references/authoring-contract.md"
    "references/brand-marks.md"
    "references/delivery-contract.md"
    "references/viewer-runtime.md"
    "renderers/shared/geometry.mjs"
    "assets/template.html"
  ];

  retarget = body:
  # Backticks in the patterns keep `schemas/` off `schemas/common.schema.json`,
  # which replaceStrings would otherwise match first.
    lib.replaceStrings
    (["node bin/archify.mjs"] ++ map (p: "`${p}`") relativePaths)
    (["archify"] ++ map (p: "`\${SKILL_DIR}/${p}`") relativePaths)
    body;

  skill = lib.custom.ai.fromClaudeSkillDir {inherit pkgs source;};
in {
  home.packages = [archify];

  programs.code-assistant-profiles.addons.archify = {
    skills.archify =
      skill
      // {
        prompt.text = retarget skill.prompt.text;
      };
  };
}
