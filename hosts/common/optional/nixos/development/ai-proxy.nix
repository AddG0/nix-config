# Points Claude Code at the Claude apps gateway on asgard, the only way to the Claude subscriptions (gitops ADR-0008).
{config, ...}: {
  # Claude Code reads the gateway URL only from this system file, never from a user's own settings.
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    forceLoginMethod = "gateway";
    forceLoginGatewayUrl = "https://ai-proxy-claude.${config.hostSpec.domain}";
    # Lets Claude Desktop pass the gateway's policy to the Claude Code sessions it starts.
    parentSettingsBehavior = "merge";
  };
}
