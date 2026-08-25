{pkgs, ...}: {
  home.packages = [pkgs.sqry];

  # sqry writes its graph into the working copy on first query.
  programs.git.ignores = [".sqry/"];

  programs.code-assistant-profiles.addons.sqry = {
    # No flags: falls back to in-process standalone, which exposes all 37 tools (daemon mode, 16).
    mcpServers.sqry = {
      command = "${pkgs.sqry}/bin/sqry-mcp";
      # Path redaction only adds correlation work — Claude already reads the files.
      env.SQRY_REDACTION_PRESET = "none";
    };

    rules.sqry.content.source = ./rule.md;
  };
}
