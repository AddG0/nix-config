# Lists each profile's manual-only skills in its startup announcements, since Claude never suggests them.
{
  config,
  lib,
  ...
}: let
  abbreviations = ["e.g." "i.e." "etc." "vs." "cf."];
  # Stands in for an abbreviation's dots while the first sentence end is found.
  dotStandIn = "․";
  mask = lib.replaceStrings abbreviations (map (lib.replaceStrings ["."] [dotStandIn]) abbreviations);
  unmask = lib.replaceStrings [dotStandIn] ["."];

  # The first sentence, or the whole description when it has no sentence end.
  summary = description: let
    flat = mask (lib.strings.trim (lib.replaceStrings ["\n"] [" "] description));
    sentence = builtins.match "(([^.!?]|[.!?][^[:space:]])*[.!?])([[:space:]].*)?" flat;
  in
    unmask (lib.removeSuffix "." (
      if sentence == null
      then flat
      else lib.head sentence
    ));

  announcement = skills: let
    manual = lib.filterAttrs (_: skill: !skill.invocation.model) skills;
    width = lib.foldl lib.max 0 (map lib.stringLength (lib.attrNames manual));
    line = name: skill:
      "  /${name}"
      + lib.optionalString (skill.description != null) "${lib.fixedWidthString (width - lib.stringLength name) " " ""}  ${summary skill.description}";
  in
    lib.optional (manual != {}) "Manual skills (Claude won't suggest these):\n${lib.concatStringsSep "\n" (lib.mapAttrsToList line manual)}";
in {
  # Per profile beneath extends, so a child lists its own manual skills once instead of inheriting its parent's list too.
  programs.claude-code-profiles.profileDefaults = lib.mapAttrs (_: profile: let
    announcements = announcement profile.skills;
  in
    lib.optionalAttrs (announcements != []) {settings.companyAnnouncements = announcements;})
  config.programs.code-assistant-profiles.resolved;
}
