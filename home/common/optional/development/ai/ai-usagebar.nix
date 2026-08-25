{
  config,
  pkgs,
  ...
}: let
  inherit (config.programs.claude-code-profiles) defaultProfile profiles;

  # Must be the file Claude Code maintains: ai-usagebar refreshes the token in
  # place, and its own ~/.claude default is a leftover with a diverged chain.
  claudeCredentials = "${config.home.homeDirectory}/${profiles.${defaultProfile}.profileDir}/.credentials.json";
in {
  home.packages = [pkgs.ai-usagebar];

  xdg.configFile."ai-usagebar/config.toml".source = (pkgs.formats.toml {}).generate "ai-usagebar-config.toml" {
    ui.primary = "anthropic";

    anthropic = {
      enabled = true;
      credentials_path = claudeCredentials;
    };

    # "openai" is the Codex CLI login (~/.codex/auth.json).
    openai.enabled = true;

    # On by default upstream; with no key they only add error rows.
    zai.enabled = false;
    openrouter.enabled = false;
  };
}
