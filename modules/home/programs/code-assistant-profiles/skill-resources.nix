# Skill directories, and the files a resourcesRoot may not hold: checked at eval for a source dir, at build for a derivation.
{lib}: let
  reserved = {
    "SKILL.md" = "SKILL.md is generated from skill metadata and prompt";
    "prompt.md" = "prompt must be provided via skill.prompt";
  };

  message = scope: name: file: "${scope} skill '${name}' resourcesRoot must not contain ${file}; ${reserved.${file}}";

  # Runs after the resources are copied, before SKILL.md is written.
  rejectReserved = scope: name:
    lib.concatMapStrings (file: ''
      if [ -e "$out/${file}" ]; then
        printf '%s\n' ${lib.escapeShellArg (message scope name file)} >&2
        exit 1
      fi
    '') (lib.attrNames reserved);
in {
  inherit message rejectReserved;

  names = lib.attrNames reserved;

  inspectableAtEval = root: !(builtins.hasContext (builtins.toString root));

  # A skill directory: the resources if any, then the generated SKILL.md, then `extraCommands` for files only one tool writes.
  mkSkillDir = {
    pkgs,
    tool,
    name,
    resourcesRoot,
    skillMd,
    extraCommands ? "",
  }:
    pkgs.runCommandLocal "${tool}-skill-${lib.strings.sanitizeDerivationName name}" {} (''
        mkdir -p "$out"
      ''
      + lib.optionalString (resourcesRoot != null) ''
        cp -R "${resourcesRoot}/." "$out/"
        ${rejectReserved tool name}
      ''
      + ''
        cp ${pkgs.writeText "SKILL.md" "${skillMd}\n"} "$out/SKILL.md"
      ''
      + extraCommands);
}
