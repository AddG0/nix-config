# Writes the default profile's Codex render to programs.codex and home.file, and every other profile as a layered profile file.
{customLib, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  codingCfg = config.programs.code-assistant-profiles;
  codexHooks = import ./hooks.nix {
    inherit lib;
    inherit (customLib) mkHookSchema;
  };

  # $CODEX_HOME/skills is deprecated upstream; ~/.agents/skills is the user root.
  skillsRelative = ".agents/skills";
  codexHomeRelative = lib.removePrefix "/" (import ../../../codex/codex-home.nix {inherit config lib;});
  skillsDir = "${config.home.homeDirectory}/${skillsRelative}";

  renderOver = base:
    import ./render.nix {
      inherit base codexHooks customLib lib pkgs;
      inherit skillsDir;
      inherit (codingCfg.targets.codex) hooks;
    };
  render = renderOver null;

  profileName = codingCfg.defaultProfile;
  hasProfile = codingCfg.enable && builtins.hasAttr profileName codingCfg.resolved;
  profile = codingCfg.resolved.${profileName};
  rendered = render profile;

  checkable = lib.filterAttrs (name: _: codingCfg.fieldTypeProblems.${name} == []) codingCfg.resolved;

  otherProfiles = removeAttrs codingCfg.resolved [profileName];

  prefixed = prefix: lib.mapAttrs' (path: lib.nameValuePair "${prefix}/${path}");

  # Codex has no per-profile agent or skill directory, so every profile's entries share the global ones.
  globalSources = checkable // {${profileName} = profile;};
  globalRenders = lib.mapAttrs (_: render) globalSources;

  # Rendered files grouped per entry: kind to entry name to its files.
  entryFiles = rendered: let
    byName = nameOf: files: lib.groupBy' (acc: file: acc // file) {} (file: nameOf (lib.head (lib.attrNames file))) (lib.mapAttrsToList (path: value: {${path} = value;}) files);
  in {
    # Commands surface as skills, so a command and a skill of one name write the same directory.
    skill = byName (path: lib.head (lib.splitString "/" path)) (rendered.commands // rendered.skills);
    agent = byName (lib.removeSuffix ".toml") rendered.agents;
  };

  defaultEntries = entryFiles rendered;
  otherEntries = lib.mapAttrs (_: entryFiles) (removeAttrs globalRenders [profileName]);

  # kind to entry name to [{profile, files}] for every non-default profile writing it.
  definers = lib.mapAttrs (kind: _:
    lib.zipAttrs (lib.mapAttrsToList (name: entries:
      lib.mapAttrs (_: files: {
        inherit files;
        profile = name;
      })
      entries.${kind})
    otherEntries))
  defaultEntries;

  # A profile's own definition replaces the default's, so Codex gets it beside the default's copy, enabled only in that profile.
  variants = lib.mapAttrs (kind: byName:
    lib.concatLists (lib.mapAttrsToList (name: versions:
      map (version: {
        inherit name;
        inherit (version) profile;
        dir = "${name}--${version.profile}";
      }) (lib.filter (version: version.files != defaultEntries.${kind}.${name}) versions))
    (lib.filterAttrs (name: _: defaultEntries.${kind} ? ${name}) byName)))
  definers;

  # Without a default copy no profile's definition is the shared one, so differing ones leave Codex nothing to fall back to.
  ambiguousEntries = lib.mapAttrs (kind: byName: lib.filterAttrs (name: versions: !(defaultEntries.${kind} ? ${name}) && lib.length (lib.unique (map (version: version.files) versions)) > 1) byName) definers;

  takenVariantNames = lib.mapAttrs (kind: list: lib.filter (variant: defaultEntries.${kind} ? ${variant.dir} || definers.${kind} ? ${variant.dir}) list) variants;

  sharedEntries = kind: lib.mapAttrs (_: versions: (lib.head versions).files) definers.${kind} // defaultEntries.${kind};

  skillPath = dir: "${skillsDir}/${dir}/SKILL.md";
  agentVariantsRelative = "agent-variants";
  variantAgentNames = lib.unique (map (variant: variant.name) variants.agent);

  globalFiles =
    prefixed skillsRelative (lib.mergeAttrsList (lib.attrValues (sharedEntries "skill") ++ map (variant: globalRenders.${variant.profile}.skillIn variant.dir variant.name) variants.skill))
    // prefixed "${codexHomeRelative}/agents" (lib.mergeAttrsList (lib.attrValues (removeAttrs (sharedEntries "agent") variantAgentNames)))
    // prefixed "${codexHomeRelative}/${agentVariantsRelative}" (
      lib.listToAttrs (map (name: lib.nameValuePair "${name}.toml" rendered.agents."${name}.toml") variantAgentNames)
      // lib.listToAttrs (map (variant: lib.nameValuePair "${variant.dir}.toml" globalRenders.${variant.profile}.agents."${variant.name}.toml") variants.agent)
    );

  # The base layer disables every profile's copy; each profile file swaps the default's copy for its own.
  defaultOverrides =
    lib.optionalAttrs (variants.skill != []) {
      skills.config =
        map (variant: {
          path = skillPath variant.dir;
          enabled = false;
        })
        variants.skill;
    }
    // lib.optionalAttrs (variantAgentNames != []) {agents = lib.genAttrs variantAgentNames (name: {config_file = "${agentVariantsRelative}/${name}.toml";});};
  profileOverrides = name: let
    own = kind: lib.filter (variant: variant.profile == name) variants.${kind};
  in
    lib.optionalAttrs (own "skill" != []) {
      skills.config = lib.concatMap (variant: [
        {
          path = skillPath variant.name;
          enabled = false;
        }
        {
          path = skillPath variant.dir;
          enabled = true;
        }
      ]) (own "skill");
    }
    // lib.optionalAttrs (own "agent" != []) {agents = lib.listToAttrs (map (variant: lib.nameValuePair variant.name {config_file = "${agentVariantsRelative}/${variant.dir}.toml";}) (own "agent"));};

  profileFile = name: layered:
    lib.optionalAttrs (layered.mcpServers != {}) {mcp_servers = layered.mcpServers;}
    // lib.optionalAttrs (layered.instructions != "") {developer_instructions = layered.instructions;}
    // profileOverrides name;
  profileFiles = lib.mapAttrs (name: other: profileFile name (renderOver profile other)) otherProfiles;
  writtenProfiles = lib.filterAttrs (_: file: file != {}) profileFiles;
  emptyProfiles = lib.attrNames (lib.filterAttrs (_: file: file == {}) profileFiles);

  writesProfile = codingCfg.targets.codex.enable && hasProfile;
in {
  imports = [(import ./options.nix {inherit codexHooks lib;})];

  # Not under the mkIf: its condition reads `targets`, which this definition is part of.
  config = lib.mkMerge [
    {
      programs.code-assistant-profiles.validators.codex = import ./validator {
        inherit config lib pkgs;
        codexHome = codexHomeRelative;
      };

      programs.code-assistant-profiles.targets.codex.writtenSkillNames =
        lib.optionals (writesProfile && config.programs.codex.enable)
        (lib.unique (lib.concatMap (source: lib.attrValues (lib.mapAttrs (name: _: name) source.commands // lib.mapAttrs (_: skill: skill.name) source.skills)) (lib.attrValues globalSources)));
    }

    (lib.mkIf (codingCfg.enable && !codingCfg.targets.codex.enable && codexHooks.render codingCfg.targets.codex.hooks != {}) {
      warnings = ["programs.code-assistant-profiles.targets.codex.hooks is set, but programs.code-assistant-profiles.targets.codex.enable is false, so no Codex hook is written"];
    })

    (lib.mkIf (codingCfg.enable && codingCfg.targets.codex.enable) {
      programs.code-assistant-profiles.droppedFields.codex = lib.mapAttrs (_: other: (render other).dropped) checkable;
    })

    (lib.mkIf writesProfile {
      programs.codex =
        {
          enable = lib.mkDefault true;
          context = rendered.instructions;
          settings = lib.optionalAttrs (rendered.mcpServers != {}) {mcp_servers = rendered.mcpServers;} // defaultOverrides;
          profiles = writtenProfiles;
        }
        // lib.optionalAttrs (rendered.hooks != {}) {inherit (rendered) hooks;};

      warnings =
        map (name: "programs.code-assistant-profiles.profiles.\"${name}\": a Codex profile carries only MCP servers, instructions and its own copies of the default's skills and agents, and these match \"${profileName}\"'s, so the codex target writes no `${name}` profile and `codex --profile ${name}` cannot select it")
        emptyProfiles;

      assertions =
        map (problem: {
          assertion = false;
          message = "programs.code-assistant-profiles.targets.codex.hooks: ${problem}";
        }) (codexHooks.problems codingCfg.targets.codex.hooks)
        ++ lib.mapAttrsToList (name: _: {
          assertion = builtins.match "[A-Za-z0-9_-]+" name != null;
          message = "programs.code-assistant-profiles.profiles.\"${name}\": Codex `--profile` accepts only letters, digits, `-` and `_`, so the codex target cannot select it";
        })
        otherProfiles
        ++ lib.concatLists (lib.mapAttrsToList (kind:
          lib.mapAttrsToList (name: versions: {
            assertion = false;
            message = "programs.code-assistant-profiles: Codex reads skills, commands and agents from global directories, so ${kind} '${name}' differs between profiles ${lib.concatMapStringsSep ", " (version: "\"${version.profile}\"") versions}, and the default profile \"${profileName}\" has no copy for one of them to replace; define it in \"${profileName}\" or rename one";
          }))
        ambiguousEntries)
        ++ lib.concatLists (lib.mapAttrsToList (kind:
          map (variant: {
            assertion = false;
            message = "programs.code-assistant-profiles: Codex writes profile \"${variant.profile}\"'s own ${kind} '${variant.name}' as '${variant.dir}', which another ${kind} is already named; rename one";
          }))
        takenVariantNames);

      home.file = lib.mkIf config.programs.codex.enable globalFiles;
    })
  ];
}
