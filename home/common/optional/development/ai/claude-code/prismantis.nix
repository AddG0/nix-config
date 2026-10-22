# Prismantis mod: themed rendering of Claude's replies, tables, code and diagrams.
{
  config,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;
in {
  programs.claude-code-profiles.baseConfig = {
    pluginDirs = [
      (pkgs.fetchFromGitHub {
        owner = "NahumLitvin";
        repo = "prismantis";
        rev = "8fa66fe36e0cba2ccda6b0ee2ba4fd5f8f40bbe8";
        hash = "sha256-vJJ08Z/a9MrrcGCnqk59onmq0IBgxZHVs1NbEuEEvcs=";
      })
    ];
    # `/prismantis theme` can't save: it writes settings.json, which is a read-only store link.
    settings.pluginConfigs."prismantis@inline".options = {
      theme = "catppuccin-mocha";
      promptStyle = "off";
      # ~630 tokens on every prompt.
      diagramHints = false;
      issueHint = false;

      accentColor = c.base0D;
      headingColor = c.base0D;
      bulletColor = c.base04;
      strongColor = c.base05;
      emphasisColor = c.base05;
      quoteColor = c.base04;
      ruleColor = c.base03;
      linkColor = c.base0D;
      pathColor = c.base0C;
      numberColor = c.base09;
      inlineCodeColor = c.base0B;
      tableHeaderColor = c.base0E;
      tableRuleColor = c.base03;
      codeTextColor = c.base05;
      codeCommentColor = c.base03;
      codeCommandColor = c.base0D;
      codeFlagColor = c.base0E;
      codeStringColor = c.base0B;
      diagramColor = c.base04;
      diagramTextColor = c.base05;
      diffAddedColor = c.base0B;
      diffRemovedColor = c.base08;
    };
  };
}
