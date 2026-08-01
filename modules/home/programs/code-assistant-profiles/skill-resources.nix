# Filenames a skill's resourcesRoot may not contain. Source dirs are checked
# during evaluation; derivation roots are checked when the skill dir is
# assembled, since only source dirs can be inspected without forcing a build.
{lib}: let
  reserved = {
    "SKILL.md" = "SKILL.md is generated from skill metadata and prompt";
    "prompt.md" = "prompt must be provided via skill.prompt";
  };

  message = scope: name: file: "${scope} skill '${name}' resourcesRoot must not contain ${file}; ${reserved.${file}}";
in {
  inherit message;

  names = lib.attrNames reserved;

  inspectableAtEval = root: !(builtins.hasContext (builtins.toString root));

  # Shell fragment for the runCommand that assembles a skill directory; run it
  # after the resources are copied, before SKILL.md is written.
  rejectReserved = scope: name:
    lib.concatMapStrings (file: ''
      if [ -e "$out/${file}" ]; then
        printf '%s\n' ${lib.escapeShellArg (message scope name file)} >&2
        exit 1
      fi
    '') (lib.attrNames reserved);
}
