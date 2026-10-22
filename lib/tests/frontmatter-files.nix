# Every frontmatter Markdown file under home/, modules/ and lib/ parses with lib.custom.frontmatter; paths stay strings so no file is copied to the store.
{lib, ...}: let
  inherit (lib.custom) frontmatter;
  root = ../..;

  # Files a module copies verbatim and never parses.
  copiedOnly = [
    # An ADR template: its `{YYYY-MM-DD}` placeholder is not YAML.
    "home/common/optional/development/ai/code-assistant-profiles/addons/architecture/skills/adr/resources/templates/adr-template.md"
  ];

  relative = lib.removePrefix "${toString root}/";
  withFrontmatter = file: lib.hasSuffix ".md" file && lib.hasPrefix "---\n" (builtins.readFile file);
  files = lib.filter (file: withFrontmatter file && !(lib.elem (relative file) copiedOnly)) (lib.concatMap (dir: map toString (lib.filesystem.listFilesRecursive (root + "/${dir}"))) ["home" "modules" "lib"]);

  parses = file: let
    parsed = frontmatter.fromText (builtins.readFile file);
  in
    (builtins.tryEval (builtins.deepSeq [parsed.attrs parsed.typedAttrs] true)).success;
in {
  "test every frontmatter Markdown file parses" = {
    expr = map relative (lib.filter (file: !(parses file)) files);
    expected = [];
  };
  "test the scan finds the repo's frontmatter files" = {
    expr = lib.length files > 50;
    expected = true;
  };
  "test each copied-only exclusion still exists and still fails to parse, so the list cannot go stale" = {
    expr = map (file: builtins.pathExists "${toString root}/${file}" && !(parses "${toString root}/${file}")) copiedOnly;
    expected = map (_: true) copiedOnly;
  };
}
