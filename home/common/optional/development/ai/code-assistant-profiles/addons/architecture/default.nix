{
  pkgs,
  lib,
  inputs,
  ...
}: let
  skillsCollection = "${inputs.claude-code-skills-collection}/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir;
in {
  programs.code-assistant-profiles.addons.architecture = {
    agents = {
      "ddd-expert".prompt.source = ./agents/ddd-expert.md;
      "system-architect".prompt.source = ./agents/system-architect.md;
    };

    skills = {
      "adr" = {
        prompt.source = ./skills/adr/prompt.md;
        resourcesRoot = ./skills/adr/resources;
      };
      "architecture-standards" = {
        prompt.source = ./skills/architecture-standards/prompt.md;
        resourcesRoot = ./skills/architecture-standards/resources;
      };
      # Copied from mattpocock/skills@49dd158 (MIT, see its LICENSE) so its references ship and we own the description.
      "codebase-design" = {
        prompt.source = ./skills/codebase-design/prompt.md;
        resourcesRoot = ./skills/codebase-design/resources;
      };
      "decision-matrix" =
        fromClaudeSkillDir {
          inherit pkgs;
          source = "${skillsCollection}/decision-matrix";
        }
        // {description = "Scores named alternatives against weighted criteria and shows the trade-offs behind a pick. Use when choosing between tools, vendors or approaches, or asked which option to go with.";};
      "security-threat-model" =
        fromClaudeSkillDir {
          inherit pkgs;
          source = "${skillsCollection}/security-threat-model";
        }
        // {description = "Builds a STRIDE threat model: trust boundaries, attack surface, threats and mitigations. Use when designing or reviewing anything that handles auth, payments, personal data or untrusted input.";};
    };

    rules.architecture.content.source = ./rules/architecture.md;
  };
}
