# The manual-skill announcements this Claude setup adds to each profile.
{
  harness,
  lib,
  ...
}: let
  manual = description: {
    prompt.text = "body";
    invocation.model = false;
    inherit description;
  };

  resolved =
    (harness.eval [
      {
        options.programs.codex = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
        };
        options.programs.opencode = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
        };
      }
      (harness.module (harness.root + "/modules/home/programs/claude-code"))
      (harness.module (harness.root + "/modules/home/programs/code-assistant-profiles"))
      ../manual-skills.nix
      {
        programs.claude-code-profiles = {
          enable = true;
          package = harness.stubs.claude;
          profiles = {
            default = {};
            child.extends = "default";
            other = {};
            plain = {};
          };
        };
        programs.code-assistant-profiles = {
          enable = true;
          profiles = {
            default.skills = {
              ship = manual "Ships the branch, e.g. after review. Then tags it.";
              bare = manual null;
              auto.prompt.text = "model-invocable";
            };
            child = {
              extends = "default";
              skills.notes = manual "Writes release notes with no sentence end";
            };
            other.skills.lone = manual "Runs v1.2 checks. Nothing else.";
            plain = {};
          };
        };
      }
    ])
    .programs
    .claude-code-profiles
    .resolved;

  announcementsOf = name: resolved.${name}.settings.companyAnnouncements or null;
in {
  testEachProfileListsItsOwnManualSkillsOnce = {
    expr = map announcementsOf ["default" "child" "other" "plain"];
    expected = [
      ["Manual skills (Claude won't suggest these):\n  /bare\n  /ship  Ships the branch, e.g. after review"]
      ["Manual skills (Claude won't suggest these):\n  /bare\n  /notes  Writes release notes with no sentence end\n  /ship   Ships the branch, e.g. after review"]
      ["Manual skills (Claude won't suggest these):\n  /lone  Runs v1.2 checks"]
      null
    ];
  };
}
