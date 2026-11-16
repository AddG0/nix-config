# T3 Code's usage hubs as t3code-hubs.nix declares them for the ai-proxy instances.
{lib, ...}: let
  settings = import ../t3code-hubs.nix {
    inherit lib;
    helper = "/fake/bin/ai-proxy";
    baseUrl = "https://proxy.example";
    claudeUrl = pool: "https://claude-${pool}.example";
    pools = ["personal" "work"];
  };
in {
  "test declares one hub for the general instance and one per Claude pool" = {
    expr = lib.mapAttrs (_: hub: hub.url) settings.usageLimitSources;
    expected = {
      ai-proxy = "https://proxy.example";
      ai-proxy-claude-personal = "https://claude-personal.example";
      ai-proxy-claude-work = "https://claude-work.example";
    };
  };

  "test every hub signs in with a fresh ai-proxy token from the command provider" = {
    expr = lib.unique (lib.mapAttrsToList (_: hub: {inherit (hub) kind managementKey;}) settings.usageLimitSources);
    expected = [
      {
        kind = "cliproxy";
        managementKey = {
          provider = "ai-proxy";
          reference = "/fake/bin/ai-proxy token";
        };
      }
    ];
  };

  "test the hubs' key comes from a command provider the settings declare" = {
    expr = settings.secretProviders;
    expected = {
      ai-proxy = {
        kind = "command";
        label = "ai-proxy";
        config = {};
      };
    };
  };
}
