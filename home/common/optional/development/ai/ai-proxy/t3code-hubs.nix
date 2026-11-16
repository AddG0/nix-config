# T3 Code settings: a usage hub per ai-proxy instance, each keyed by `ai-proxy token` through an uncached command provider (ADR 0025).
{
  lib,
  helper,
  baseUrl,
  claudeUrl,
  pools,
}: let
  provider = "ai-proxy";

  hubs =
    {
      ai-proxy = {
        label = "AI proxy";
        url = baseUrl;
      };
    }
    // lib.listToAttrs (map (pool:
      lib.nameValuePair "ai-proxy-claude-${pool}" {
        label = "AI proxy · Claude ${pool}";
        url = claudeUrl pool;
      })
    pools);
in {
  secretProviders.${provider} = {
    kind = "command";
    label = provider;
    config = {};
  };

  usageLimitSources = lib.mapAttrs (_: hub:
    hub
    // {
      kind = "cliproxy";
      managementKey = {
        inherit provider;
        reference = "${helper} token";
      };
    })
  hubs;
}
