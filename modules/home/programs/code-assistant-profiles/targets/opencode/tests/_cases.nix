# The opencode target's renders and evaluated fixtures, shared by its unit and files tests.
{
  harness,
  lib,
  pkgs,
}: let
  inherit (import ../../../tests/_fixtures.nix {inherit harness lib pkgs;}) agentWithModel codexHookTargets evalTargets failedOf fixtureBody fixtureFile forced frontmatter invocationConfig invocationProfile libWithCustom needleProblems noNeedleProblems optionalFieldsConfig spec typed;

  renderOpencodeWith = {
    codexSkillNames ? [],
    plugins ? {},
  }:
    import ../render.nix {
      inherit codexSkillNames pkgs plugins;
      lib = libWithCustom;
      customLib = libWithCustom.custom;
      skillsDir = "/home/t/.config/opencode/skills";
    };

  toOpencode = raw: renderOpencodeWith {} (typed raw);

  opencodeAgents = agents: (toOpencode {inherit agents;}).agents;
  inherit (import ../../../options/fields.nix {inherit lib;}) agentColors;
  hexColored = map (color: builtins.match ".*color: '#[0-9A-F]{6}'.*" (opencodeAgents {a = (agentWithModel null) // {inherit color;};}).a != null) agentColors;
  remoteMcp =
    (toOpencode {
      mcpServers.r = {
        type = "remote";
        url = "https://mcp.example";
        headers.Authorization = "Bearer t";
      };
    }).mcpServers.r;
  remoteMcpWithoutHeaders =
    (toOpencode {
      mcpServers.r = {
        type = "remote";
        url = "https://mcp.example";
      };
    }).mcpServers.r;
  lspRendered = toOpencode {
    lspServers.l = {
      command = "l";
      extensionToLanguage.".l" = "l";
    };
  };

  invocationRendered = toOpencode invocationConfig;
  opencodeSkill = name: invocationRendered.skills.definitions.${name};
  permissionOf = agent: (opencodeAgents {a = (agentWithModel null) // agent;}).a;

  optionalRendered = toOpencode optionalFieldsConfig;
  opencodeMcp = optionalRendered.mcpServers;
  opencodeLsp = optionalRendered.lspServers;
  plugins = {
    "notify.js" = "export const Notify = async () => ({})";
    "guard.ts" = ../../../tests/fixtures/clean/reference.md;
  };
  pluginConfig = codexHookTargets {} plugins;
  renderedPlugins = (renderOpencodeWith {inherit plugins;} (typed {})).hooks;
in {
  inherit agentColors agentWithModel codexHookTargets evalTargets failedOf fixtureBody fixtureFile forced frontmatter hexColored invocationConfig invocationProfile invocationRendered libWithCustom lspRendered needleProblems noNeedleProblems opencodeAgents opencodeLsp opencodeMcp opencodeSkill optionalFieldsConfig optionalRendered permissionOf pluginConfig plugins remoteMcp remoteMcpWithoutHeaders renderOpencodeWith renderedPlugins spec toOpencode typed;
}
