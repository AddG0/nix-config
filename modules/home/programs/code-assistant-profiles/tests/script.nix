# agent-run, the launcher, and the reserved-file guard a skill resourcesRoot
# passes through; the cases live in the .bats files beside this.
{
  harness,
  lib,
  pkgs,
  self,
  ...
}: let
  launcherModule = import ../launcher.nix {inherit lib pkgs;};
  guard = pkgs.writeShellScript "reject-reserved" ''
    out=$1
    ${(import ../skill-resources.nix {inherit lib;}).rejectReserved "codex" "demo"}
  '';

  # The packages the home config installs for each target, from the pins and overlays the hosts use.
  hostPkgs = import self.inputs.nixpkgs {
    inherit (pkgs.stdenv.hostPlatform) system;
    overlays = [self.overlays.default];
    config.allowUnfree = true;
  };
  installed = {
    claude-code = hostPkgs.unstable.claude-code;
    inherit (hostPkgs) codex opencode;
  };

  # Every word the launcher passes as a flag or flag value must still appear in the tool's --help.
  flagWords = spec: lib.filter (word: word != null) (spec.autoApprove ++ [spec.promptFlag]);
  helpChecks = builtins.toJSON (lib.mapAttrsToList (target: spec: {
      inherit target;
      binary = lib.getExe' installed.${target} spec.binary;
      version = "${lib.getName installed.${target}} ${lib.getVersion installed.${target}}";
      words = flagWords spec;
    })
    launcherModule.specs);

  # Stubs make the generated invocation observable rather than inferred.
  stubAgent = name:
    pkgs.writeShellScriptBin name ''
      echo "BINARY=${name}"
      echo "CWD=$PWD"
      printf '%s\n' "$@"
    '';

  stubBin = pkgs.symlinkJoin {
    name = "agent-run-stubs";
    paths = map stubAgent ["claude" "codex" "opencode"];
  };

  mkLauncher = {
    agents,
    defaultAgent,
    skillNames ? ["diagnose-crash" "nix-build"],
  }:
    launcherModule.mkLauncher {
      inherit agents defaultAgent skillNames;
      profileBinDir = "/nonexistent/profile/bin";
    };

  allAgents = mkLauncher {
    agents = ["claude-code" "codex" "opencode"];
    defaultAgent = "claude-code";
  };

  noDefault = mkLauncher {
    agents = ["claude-code" "codex" "opencode"];
    defaultAgent = null;
  };

  claudeOnly = mkLauncher {
    agents = ["claude-code"];
    defaultAgent = "claude-code";
  };

  noSkills = mkLauncher {
    agents = ["claude-code"];
    defaultAgent = "claude-code";
    skillNames = [];
  };
in
  harness.bats "code-assistant-profiles-script" [./agent-run.bats ./skill-resources.bats] {
    nativeBuildInputs = [pkgs.jq];
    stubBin = "${stubBin}/bin";
    agentRun = "${allAgents}/bin/agent-run";
    claudeOnlyAgentRun = "${claudeOnly}/bin/agent-run";
    noSkillsAgentRun = "${noSkills}/bin/agent-run";
    noDefaultAgentRun = "${noDefault}/bin/agent-run";
    inherit guard helpChecks;
  }
